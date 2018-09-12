require 'fhir_client'
require 'pry'
#require File.expand_path '../../../app.rb', __FILE__
#require './models/testing_instance'
require 'dm-core'
require 'csv'
require 'colorize'
require 'optparse'

require_relative '../app'
require_relative '../app/endpoint'
require_relative '../app/helpers/configuration'
require_relative '../app/sequence_base'
require_relative '../app/models'

#['lib', 'models'].each do |dir|
#  Dir.glob(File.join(File.expand_path('../..', File.dirname(File.absolute_path(__FILE__))),dir, '**','*.rb')).each do |file|
#    require file
#  end
#end
#
#
#

include Inferno

namespace :inferno do |argv|

  desc 'Generate List of All Tests'
  task :tests_to_csv, [:group, :filename] do |task, args|
    args.with_defaults(group: 'active', filename: 'testlist.csv')
    case args.group
    when 'active'
      test_group = Inferno::Sequence::SequenceBase.ordered_sequences.reject {|sb| sb.inactive?}
    when 'inactive'
      test_group = Inferno::Sequence::SequenceBase.ordered_sequences.select {|sb| sb.inactive?}
    when 'all'
      test_group = Inferno::Sequence::SequenceBase.ordered_sequences
    else
      puts "#{args.group} is not valid argument.  Valid arguments include:
                  active
                  inactive
                  all"
      exit
    end

    flat_tests = test_group.map  do |klass|
      klass.tests.map do |test|
        test[:sequence] = klass.to_s
        test[:sequence_required] = !klass.optional?
        test
      end
    end.flatten

    csv_out = CSV.generate do |csv|
      csv << ['Version', VERSION, 'Generated', Time.now]
      csv << ['', '', '', '', '']
      csv << ['Test ID', 'Reference', 'Sequence/Group', 'Test Name', 'Required?', 'Description/Requirement', 'Reference URI']
      flat_tests.each do |test|
        csv <<  [test[:test_id], test[:ref], test[:sequence], test[:name], test[:sequence_required] && test[:required], test[:description], test[:url] ]
      end
    end

    File.write(args.filename, csv_out)

  end

  desc 'Execute sequence against a FHIR server'
  task :execute, [:server] do |task, args|
    sequences = []
    requires = []
    defines = []

    Inferno::Sequence::SequenceBase.ordered_sequences.each do |seq|
      if args.extras.include? seq.sequence_name.split('Sequence')[0]
        sequences << seq
        seq.requires.each do |req|
          oauth_required ||= (req == :initiate_login_uri)
          requires << req unless (requires.include?(req) || defines.include?(req) || req == :url)
        end
        defines.push(*seq.defines)
      end
    end

    instance = Inferno::Models::TestingInstance.new(url: args[:server])
    instance.save!
    client = FHIR::Client.new(args[:server])
    client.use_dstu2
    client.default_json
    # sequence_result = sequence_instance.start

    o = OptionParser.new

    o.banner = "Usage: rake inferno:execute [options]"
    requires.each do |req|
      o.on("--#{req.to_s} #{req.to_s.upcase}") do  |value|
        instance.send("#{req.to_s}=", value) if instance.respond_to? req.to_s
      end
    end

    # return `ARGV` with the intended arguments
    args = o.order!(ARGV) {}

    o.parse!(args)

    if requires.include? :client_id
      puts 'Please register the application with the following information (enter to continue)'
      #FIXME
      puts "Launch URI: http://localhost:4567/#{base_path}/#{instance.id}/#{instance.client_endpoint_key}/launch"
      puts "Redirect URI: http://localhost:4567/#{base_path}/#{instance.id}/#{instance.client_endpoint_key}/redirect"
      STDIN.getc
      print "            \r"
    end

    input_required = false
    requires.each do |req|
      if instance.respond_to?(req) && instance.send(req).nil?
        puts "\n\nENTER REQUIRED FIELDS\n".blue unless input_required
        print "Enter #{req.to_s.upcase}: "
        instance.send("#{req}=", gets.chomp)
        input_required = true
      end
    end
    instance.save!

    if input_required
      puts ""
      puts "\nIn the future, run with the following command".blue
      puts "TODO bundle exec rake[asdfasdf,asdfsadf] -- --PARAM_1 value --PARAM_2 value"
      puts ""
      print "(enter to continue)"
      STDIN.getc
      print "            \r"
    end

    fails = false

    sequences.each do |sequence|

      sequence_instance = sequence.new(instance, client, true)
      sequence_result = sequence_instance.start

      checkmark = "\u2713"
      puts sequence.sequence_name + " Sequence: "
      sequence_result.test_results.each do |result|
        print "\tTest: #{result.name} - "
        if result.result == 'pass'
          puts 'pass '.green + checkmark.encode('utf-8').green
        elsif result.result == 'skip'
          puts 'skip '.yellow + '*'.yellow
        elsif result.result == 'fail'
          if result.required == 'true'
            puts 'fail '.red + 'X'.red + ' ' + result.message
          else
            puts 'fail X (optional)'.light_black + ' ' + result.message
          end
        elsif sequence_result.result == 'error'
          puts 'error '.magenta + 'X'.magenta + ' ' + result.message
          fails = true
        end
      end
      print sequence.sequence_name + " Sequence Result: "
      if sequence_result.result == 'pass'
        puts 'pass '.green + checkmark.encode('utf-8').green
      elsif sequence_result.result == 'fail'
        puts 'fail '.red + 'X'.red
        fails = true
      elsif sequence_result.result == 'error'
        puts 'error '.magenta + 'X'.magenta
        fails = true
      else
        binding.pry
      end
    end

    # puts "hello #{options[:name]}"

    if fails
      exit 1
    else
      exit 0
    end
  end

  desc 'Execute sequence against a FHIR server'
  task :execute_sequence, [:sequence, :server] do |task, args|

    @sequence = nil
    Inferno::Sequence::SequenceBase.ordered_sequences.map do |seq|
      if seq.sequence_name == args[:sequence] + "Sequence"
        @sequence = seq
      end
    end

    if @sequence == nil
      puts "Sequence not found. Valid sequences are:
              Conformance,
              DynamicRegistration,
              PatientStandaloneLaunch,
              ProviderEHRLaunch,
              OpenIDConnect,
              TokenIntrospection,
              TokenRefresh,
              ArgonautDataQuery,
              ArgonautProfiles,
              AdditionalResources"
      exit
    end

    instance = Inferno::Models::TestingInstance.new(url: args[:server])
    instance.save!
    client = FHIR::Client.new(args[:server])
    client.use_dstu2
    client.default_json
    sequence_instance = @sequence.new(instance, client, true)
    sequence_result = sequence_instance.start
    binding.pry

    checkmark = "\u2713"
    puts @sequence.sequence_name + " Sequence: "
    sequence_result.test_results.each do |result|
      print "\tTest: #{result.name} - "
      if result.result == 'pass'
        puts 'pass '.green + checkmark.encode('utf-8').green
      elsif result.result == 'skip'
        puts 'skip '.yellow + '*'.yellow
      elsif result.result == 'fail'
        if result.required == 'true'
          puts 'fail '.red + 'X'.red
        else
          puts 'fail X (optional)'.light_black
        end
      end
    end
    print @sequence.sequence_name + " Sequence Result: "
    if sequence_result.result == 'pass'
      puts 'pass '.green + checkmark.encode('utf-8').green
    elsif sequence_result.result == 'fail'
      puts 'fail '.red + 'X'.red
      exit 1
    end


  end

end
