module Inferno
  module Sequence
    class ArgonautAllergyIntoleranceSequence < SequenceBase

      group 'Argonaut Profile Conformance'

      title 'Allergy Intolerance'

      description 'Verify that AllergyIntolerance resources on the FHIR server follow the Argonaut Data Query Implementation Guide'

      test_id_prefix 'ARAI'

      requires :token, :patient_id
      conformance_supports :AllergyIntolerance

      @resources_found = false

      test 'Server rejects AllergyIntolerance search without authorization' do

        metadata {
          id '01'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          desc %(
            An AllergyIntolerance search does not work without proper authorization.
          )
          versions :dstu2
        }

        @client.set_no_auth
        skip 'Could not verify this functionality when bearer token is not set' if @instance.token.blank?

        reply = get_resource_by_params(versioned_resource_class('AllergyIntolerance'), {patient: @instance.patient_id})
        @client.set_bearer_token(@instance.token)
        assert_response_unauthorized reply

      end

      test 'Server returns expected results from AllergyIntolerance search by patient' do

        metadata {
          id '02'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          desc %(
            A server is capable of returning a patient's allergies.
          )
          versions :dstu2
        }

        reply = get_resource_by_params(versioned_resource_class('AllergyIntolerance'), {patient: @instance.patient_id})
        assert_response_ok(reply)
        assert_bundle_response(reply)

        resource_count = reply.try(:resource).try(:entry).try(:length) || 0
        if resource_count > 0
          @resources_found = true
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        @allergyintolerance = reply.try(:resource).try(:entry).try(:first).try(:resource)
        validate_search_reply(versioned_resource_class('AllergyIntolerance'), reply)
        save_resource_ids_in_bundle(versioned_resource_class('AllergyIntolerance'), reply)

      end

      test 'Server returns expected results from AllergyIntolerance read resource' do

        metadata {
          id '03'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          desc %(
            All servers SHALL make available the read interactions for the Argonaut Profiles the server chooses to support.
          )
          versions :dstu2
        }

        skip_if_not_supported(:AllergyIntolerance, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_read_reply(@allergyintolerance, versioned_resource_class('AllergyIntolerance'))

      end

      test 'AllergyIntolerance history resource supported' do

        metadata {
          id '04'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          optional
          desc %(
            All servers SHOULD make available the vread and history-instance interactions for the Argonaut Profiles the server chooses to support.
          )
          versions :dstu2
        }

        skip_if_not_supported(:AllergyIntolerance, [:history])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        validate_history_reply(@allergyintolerance, versioned_resource_class('AllergyIntolerance'))

      end

      test 'AllergyIntolerance vread resource supported' do

        metadata {
          id '05'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          optional
          desc %(
            All servers SHOULD make available the vread and history-instance interactions for the Argonaut Profiles the server chooses to support.
          )
          versions :dstu2
        }

        skip_if_not_supported(:AllergyIntolerance, [:vread])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_vread_reply(@allergyintolerance, versioned_resource_class('AllergyIntolerance'))

      end

      test 'AllergyIntolerance resources associated with Patient conform to Argonaut profiles' do

        metadata {
          id '06'
          link 'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-allergyintolerance.html'
          desc %(
            AllergyIntolerance resources associated with Patient conform to Argonaut profiles
          )
          versions :dstu2
        }
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found
        test_resources_against_profile('AllergyIntolerance')
      end

      test 'All references can be resolved' do

        metadata {
          id '07'
          link 'https://www.hl7.org/fhir/DSTU2/references.html'
          desc %(
            All references in the AllergyIntolerance resource should be resolveable.
          )
          versions :dstu2
        }

        skip_if_not_supported(:AllergyIntolerance, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_reference_resolutions(@allergyintolerance)

      end


    end

  end
end
