module Inferno
  module Sequence
    class ArgonautObservationSequence < SequenceBase

      title 'Observation'

      description 'Verify that Observation resources on the FHIR server follow the Argonaut Data Query Implementation Guide'

      test_id_prefix 'AROB'

      requires :token, :patient_id
      conformance_supports :Observation

      @resources_found = false

      test 'Observation Results search without authorization' do

        metadata {
          id '01'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          desc %(
            An Observation Results search does not work without proper authorization.
          )
          versions :dstu2
        }

        @client.set_no_auth
        skip 'Could not verify this functionality when bearer token is not set' if @instance.token.blank?

        reply = get_resource_by_params(versioned_resource_class('Observation'), {patient: @instance.patient_id, category: "laboratory"})
        @client.set_bearer_token(@instance.token)
        assert_response_unauthorized reply

      end

      test 'Server returns expected results from Observation Results search by patient + category' do

        metadata {
          id '02'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          desc %(
            A server is capable of returning all of a patient's laboratory results queried by category.
          )
          versions :dstu2
        }

        reply = get_resource_by_params(versioned_resource_class('Observation'), {patient: @instance.patient_id, category: "laboratory"})
        assert_response_ok(reply)
        assert_bundle_response(reply)

        resource_count = reply.try(:resource).try(:entry).try(:length) || 0
        if resource_count > 0
          @resources_found = true
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        @observationresults = reply.try(:resource).try(:entry).try(:first).try(:resource)
        validate_search_reply(versioned_resource_class('Observation'), reply)
        save_resource_ids_in_bundle(versioned_resource_class('Observation'), reply)

      end

      test 'Server returns expected results from Observation Results search by patient + category + date' do

        metadata {
          id '03'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          desc %(
            A server is capable of returning all of a patient's laboratory results queried by category code and date range.
          )
          versions :dstu2
        }

        skip_if_not_supported(:Observation, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        assert !@observationresults.nil?, 'Expected valid Observation resource to be present'
        date = @observationresults.try(:effectiveDateTime)
        assert !date.nil?, "Observation effectiveDateTime not returned"
        reply = get_resource_by_params(versioned_resource_class('Observation'), {patient: @instance.patient_id, category: "laboratory", date: date})
        validate_search_reply(versioned_resource_class('Observation'), reply)

      end

      test 'Server returns expected results from Observation Results search by patient + category + code' do

        metadata {
          id '04'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          desc %(
            A server is capable of returning all of a patient's laboratory results queried by category and code.
          )
          versions :dstu2
        }

        skip_if_not_supported(:Observation, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        assert !@observationresults.nil?, 'Expected valid Observation resource to be present'
        code = @observationresults.try(:code).try(:coding).try(:first).try(:code)
        assert !code.nil?, "Observation code not returned"
        reply = get_resource_by_params(versioned_resource_class('Observation'), {patient: @instance.patient_id, category: "laboratory", code: code})
        validate_search_reply(versioned_resource_class('Observation'), reply)

      end

      test 'Server returns expected results from Observation Results search by patient + category + code + date' do

        metadata {
          id '05'
          optional
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          desc %(
            A server SHOULD be capable of returning all of a patient's laboratory results queried by category and one or more codes and date range.
          )
          versions :dstu2
        }

        skip_if_not_supported(:Observation, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        assert !@observationresults.nil?, 'Expected valid Observation resource to be present'
        code = @observationresults.try(:code).try(:coding).try(:first).try(:code)
        assert !code.nil?, "Observation code not returned"
        date = @observationresults.try(:effectiveDateTime)
        assert !date.nil?, "Observation effectiveDateTime not returned"
        reply = get_resource_by_params(versioned_resource_class('Observation'), {patient: @instance.patient_id, category: "laboratory", code: code, date: date})
        validate_search_reply(versioned_resource_class('Observation'), reply)

      end

      test 'Server rejects Smoking Status search without authorization' do

        metadata {
          id '06'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          desc %(
            A Smoking Status search does not work without proper authorization.
          )
          versions :dstu2
        }

        skip_if_not_supported(:Observation, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        @client.set_no_auth
        skip 'Could not verify this functionality when bearer token is not set' if @instance.token.blank?

        reply = get_resource_by_params(versioned_resource_class('Observation'), {patient: @instance.patient_id, code: "72166-2"})
        @client.set_bearer_token(@instance.token)
        assert_response_unauthorized reply

      end

      test 'Server returns expected results from Smoking Status search by patient + code' do

        metadata {
          id '07'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          desc %(
            A server is capable of returning a patient's smoking status.
          )
          versions :dstu2
        }

        skip_if_not_supported(:Observation, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        reply = get_resource_by_params(versioned_resource_class('Observation'), {patient: @instance.patient_id, code: "72166-2"})
        validate_search_reply(versioned_resource_class('Observation'), reply)
        # TODO check for 72166-2
        save_resource_ids_in_bundle(versioned_resource_class('Observation'), reply)

      end

      test 'Observation read resource supported' do

        metadata {
          id '08'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          desc %(
            All servers SHALL make available the read interactions for the Argonaut Profiles the server chooses to support.
          )
          versions :dstu2
        }

        skip_if_not_supported(:Observation, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_read_reply(@observationresults, versioned_resource_class('Observation'))

      end

      test 'Observation history resource supported' do

        metadata {
          id '09'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          optional
          desc %(
            All servers SHOULD make available the vread and history-instance interactions for the Argonaut Profiles the server chooses to support.
          )
          versions :dstu2
        }

        skip_if_not_supported(:Observation, [:history])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_history_reply(@observationresults, versioned_resource_class('Observation'))

      end

      test 'Observation vread resource supported' do

        metadata {
          id '10'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          optional
          desc %(
            All servers SHOULD make available the vread and history-instance interactions for the Argonaut Profiles the server chooses to support.
          )
          versions :dstu2
        }

        skip_if_not_supported(:Observation, [:vread])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_vread_reply(@observationresults, versioned_resource_class('Observation'))

      end

      test 'Observation Result resources associated with Patient conform to Argonaut profiles' do

        metadata {
          id '11'
          link 'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-observationresults.html'
          desc %(
            Observation Result resources associated with Patient conform to Argonaut profiles.
          )
          versions :dstu2
        }

        test_resources_against_profile('Observation', Inferno::ValidationUtil::ARGONAUT_URIS[:observation_results])
        skip_unless @profiles_encountered.include?(Inferno::ValidationUtil::ARGONAUT_URIS[:observation_results]), 'No Observation Results found.'
        assert !@profiles_failed.include?(Inferno::ValidationUtil::ARGONAUT_URIS[:observation_results]), "Observation Results failed validation.<br/>#{@profiles_failed[Inferno::ValidationUtil::ARGONAUT_URIS[:observation_results]]}"
      end

      test 'All references can be resolved' do

        metadata {
          id '12'
          link 'https://www.hl7.org/fhir/DSTU2/references.html'
          desc %(
            All references in the Observation resource should be resolveable.
          )
          versions :dstu2
        }

        skip_if_not_supported(:Observation, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_reference_resolutions(@observationresults)

      end

    end

  end
end
