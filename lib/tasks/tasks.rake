require 'fhir_client'
require 'pry'
require 'dm-core'
require 'csv'
require 'colorize'
require 'optparse'

require_relative '../app'
require_relative '../app/endpoint'
require_relative '../app/helpers/configuration'
require_relative '../app/sequence_base'
require_relative '../app/models'
require_relative '../app/utils/instance_config'

include Inferno

def suppress_output
  begin
    original_stderr = $stderr.clone
    original_stdout = $stdout.clone
    $stderr.reopen(File.new('/dev/null', 'w'))
    $stdout.reopen(File.new('/dev/null', 'w'))
    retval = yield
  rescue Exception => e
    $stdout.reopen(original_stdout)
    $stderr.reopen(original_stderr)
    raise e
  ensure
    $stdout.reopen(original_stdout)
    $stderr.reopen(original_stderr)
  end
  retval
end

def print_requests(result)
  result.request_responses.map do |req_res|
    req_res.response_code.to_s + ' ' + req_res.request_method.upcase + ' ' + req_res.request_url
  end
end

def execute(instance, sequences)

  client = FHIR::Client.new(instance.url)

  client.use_dstu2 if instance.module.fhir_version == 'dstu2'

  client.default_json

  sequence_results = []

  fails = false

  system "clear"
  puts "\n"
  puts "==========================================\n"
  puts " Testing #{sequences.length} Sequences"
  puts "==========================================\n"
  sequences.each do |sequence_info|

    sequence = sequence_info['sequence']
    sequence_info.each do |key, val|
      if key != 'sequence'
        if val.is_a?(Array) || val.is_a?(Hash)
          instance.send("#{key.to_s}=", val.to_json) if instance.respond_to? key.to_s
        elsif val.is_a?(String) && val.downcase == 'true'
          instance.send("#{key.to_s}=", true) if instance.respond_to? key.to_s
        elsif val.is_a?(String) && val.downcase == 'false'
          instance.send("#{key.to_s}=", false) if instance.respond_to? key.to_s
        else
          instance.send("#{key.to_s}=", val) if instance.respond_to? key.to_s
        end
      end
    end
    instance.save
    sequence_instance = sequence.new(instance, client, false)
    sequence_result = nil

    suppress_output{sequence_result = sequence_instance.start}

    sequence_results << sequence_result

    checkmark = "\u2713"
    puts "\n" + sequence.sequence_name + " Sequence: \n"
    sequence_result.test_results.each do |result|
      print " "
      if result.result == 'pass'
        print "#{checkmark.encode('utf-8')} pass".green
        print " - #{result.test_id} #{result.name}\n"
      elsif result.result == 'skip'
        print "* skip".yellow
        print " - #{result.test_id} #{result.name}\n"
        puts "    Message: #{result.message}"
      elsif result.result == 'fail'
        if result.required
          print "X fail".red
          print " - #{result.test_id} #{result.name}\n"
          puts "    Message: #{result.message}"
          print_requests(result).map do |req|
            puts "    #{req}"
          end
          fails = true
        else
          print "X fail (optional)".light_black
          print " - #{result.test_id} #{result.name}\n"
          puts "    Message: #{result.message}"
          print_requests(result).map do |req|
            puts "    #{req}"
          end
        end
      elsif sequence_result.result == 'error'
        print "X error".magenta
        print " - #{result.test_id} #{result.name}\n"
        puts "    Message: #{result.message}"
        print_requests(result).map do |req|
          puts "      #{req}"
        end
        fails = true
      end
    end
    print "\n" + sequence.sequence_name + " Sequence Result: "
    if sequence_result.result == 'pass'
      puts 'pass '.green + checkmark.encode('utf-8').green
    elsif sequence_result.result == 'fail'
      puts 'fail '.red + 'X'.red
      fails = true
    elsif sequence_result.result == 'error'
      puts 'error '.magenta + 'X'.magenta
      fails = true
    elsif sequence_result.result == 'skip'
      puts 'skip '.yellow + '*'.yellow
    end
    puts "---------------------------------------------\n"
  end

  failures_count = "" + sequence_results.select{|s| s.result == 'fail'}.count.to_s
  passed_count = "" + sequence_results.select{|s| s.result == 'pass'}.count.to_s
  skip_count = "" + sequence_results.select{|s| s.result == 'skip'}.count.to_s
  print " Result: " + failures_count.red + " failed, " + passed_count.green + " passed"
  if sequence_results.select{|s| s.result == 'skip'}.count > 0
    print (", " + sequence_results.select{|s| s.result == 'skip'}.count.to_s).yellow + " skipped"
  end
  if sequence_results.select{|s| s.result == 'error'}.count > 0
    print (", " + sequence_results.select{|s| s.result == 'error'}.count.to_s).yellow + " error"
  end
  puts "\n=============================================\n"

  return_value = 0
  return_value = 1 if fails

  return_value

end

namespace :inferno do |argv|

  # Exports a CSV containing the test metadata
  desc 'Generate List of All Tests'
  task :tests_to_csv, [:module, :group, :filename] do |task, args|
    args.with_defaults(module: 'argonaut', group: 'active')
    args.with_defaults(filename: "#{args.module}_testlist.csv")
    sequences = Inferno::Module.get(args.module)&.sequences
    if sequences.nil?
      puts "No sequence found for module: #{args.module}"
      exit
    end

    flat_tests = sequences.map  do |klass|
      klass.tests.map do |test|
        test[:sequence] = klass.to_s
        test[:sequence_required] = !klass.optional?
        test
      end
    end.flatten

    csv_out = CSV.generate do |csv|
      csv << ['Version', VERSION, 'Generated', Time.now]
      csv << ['', '', '', '', '']
      csv << ['Test ID', 'Reference', 'Sequence/Group', 'Test Name', 'Required?', 'Reference URI']
      flat_tests.each do |test|
        csv <<  [test[:test_id], test[:ref], test[:sequence].split("::").last, test[:name], test[:sequence_required] && test[:required], test[:url] ]
      end
    end

    File.write(args.filename, csv_out)
    puts "Writing to #{args.filename}"
  end

  desc 'Generate automated run script'
  task :generate_script, [:server,:module] do |task, args|

    sequences = []
    requires = []
    defines = []

    input = ''

    output = {server: args[:server], module: args[:module], arguments: {}, sequences: []}

    instance = Inferno::Models::TestingInstance.new(url: args[:server], selected_module: args[:module])
    instance.save!

    instance.module.sequences.each do |seq|
      unless input == 'a'
        print "\nInclude #{seq.sequence_name} (y/n/a)? "
        input = STDIN.gets.chomp
      end

      if input == 'a' || input == 'y'
        output[:sequences].push({sequence: seq.sequence_name})
        sequences << seq
        seq.requires.each do |req|
          requires << req unless (requires.include?(req) || defines.include?(req) || req == :url)
        end
        defines.push(*seq.defines)
      end
    end

    STDOUT.print "\n"

    requires.each do |req|
      input = ""

      if req == :initiate_login_uri
        input = 'http://localhost:4568/launch'
      elsif req == :redirect_uris
        input = 'http://localhost:4568/redirect'
      else
        STDOUT.flush
        STDOUT.print "\nEnter #{req.to_s.upcase}: ".light_black
        STDOUT.flush
        input = STDIN.gets.chomp
      end

      output[:arguments][req] = input
    end

    File.open('script.json', 'w') { |file| file.write(JSON.pretty_generate(output)) }

  end

  desc 'Execute sequences against a FHIR server'
  task :execute, [:server,:module] do |task, args|

    FHIR.logger.level = Logger::UNKNOWN
    sequences = []
    requires = []
    defines = []

    instance = Inferno::Models::TestingInstance.new(url: args[:server], selected_module: args[:module])
    instance.save!

    instance.module.sequences.each do |seq|
      if args.extras.empty? || args.extras.include?(seq.sequence_name.split('Sequence')[0])
        seq.requires.each do |req|
          oauth_required ||= (req == :initiate_login_uri)
          requires << req unless (requires.include?(req) || defines.include?(req) || req == :url)
        end
        defines.push(*seq.defines)
        sequences << seq
      end
    end

    o = OptionParser.new

    o.banner = "Usage: rake inferno:execute [options]"
    requires.each do |req|
      o.on("--#{req.to_s} #{req.to_s.upcase}") do  |value|
        instance.send("#{req.to_s}=", value) if instance.respond_to? req.to_s
      end
    end

    arguments = o.order!(ARGV) {}

    o.parse!(arguments)

    if requires.include? :client_id
      puts 'Please register the application with the following information (enter to continue)'
      #FIXME
      puts "Launch URI: http://localhost:4567/#{base_path}/#{instance.id}/#{instance.client_endpoint_key}/launch"
      puts "Redirect URI: http://localhost:4567/#{base_path}/#{instance.id}/#{instance.client_endpoint_key}/redirect"
      STDIN.getc
      print "            \r"
    end

    input_required = false
    param_list = ""
    requires.each do |req|
      if instance.respond_to?(req) && instance.send(req).nil?
        puts "\nPlease provide the following required fields:\n" unless input_required
        print "  #{req.to_s.upcase}: ".light_black
        value_input = gets.chomp
        instance.send("#{req}=", value_input)
        input_required = true
        param_list = "#{param_list} --#{req.to_s.upcase} #{value_input}"
      end
    end
    instance.save!

    if input_required
      args_list = "#{instance.url},#{args.module}"
      args_list = args_list + ",#{args.extras.join(',')}" unless args.extras.empty?

      puts ""
      puts "\nIn the future, run with the following command:\n\n"
      puts "  rake inferno:execute[#{args_list}] -- #{param_list}".light_black
      puts ""
      print "(enter to continue)".red
      STDIN.getc
      print "            \r"
    end

    exit execute(instance, sequences.map{|s| {'sequence' => s}})

  end

  desc 'Cleans the database of all models'
  task :drop_database, [] do |task|
    DataMapper.auto_migrate!
  end

  desc 'Execute sequence against a FHIR server'
  task :execute_batch, [:config] do |task, args|
    file = File.read(args.config)
    config = JSON.parse(file)

    instance = Inferno::Models::TestingInstance.new(url: config['server'], selected_module: config['module'], initiate_login_uri: 'http://localhost:4568/launch', redirect_uris: 'http://localhost:4568/redirect')
    instance.save!
    client = FHIR::Client.new(config['server'])
    client.use_dstu2 if instance.module.fhir_version == 'dstu2'
    client.default_json

    configure_instance(instance, config['arguments'])

    sequences = config['sequences'].map do |sequence|
      sequence_name = sequence
      out = {}
      if !sequence.is_a?(Hash)
        out = {
          'sequence' => Inferno::Sequence::SequenceBase.descendants.find{|x| x.sequence_name.start_with?(sequence_name)}
        }
      else
        out = sequence
        out['sequence'] = Inferno::Sequence::SequenceBase.descendants.find{|x| x.sequence_name.start_with?(sequence['sequence'])}
      end

      out

    end

    exit execute(instance, sequences)
  end
end
