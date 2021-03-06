module Inferno
  module Sequence
    class ArgonautCareTeamSequence < SequenceBase

      group 'Argonaut Profile Conformance'

      title 'Care Team'

      description 'Verify that CareTeam resources on the FHIR server follow the Argonaut Data Query Implementation Guide'

      test_id_prefix 'ARCT'

      requires :token, :patient_id
      conformance_supports :CarePlan

      @resources_found = false

      test 'Server returns expected CareTeam results from CarePlan search by patient + category' do

        metadata {
          id '01'
          link 'http://www.fhir.org/guides/argonaut/r2/Conformance-server.html'
          desc %(
            A server is capable of returning all of a patient's Assessment and Plan of Treatment information.
          )
          versions :dstu2
        }

        reply = get_resource_by_params(versioned_resource_class('CarePlan'), {patient: @instance.patient_id, category: "careteam"})
        @careteam = reply.try(:resource).try(:entry).try(:first).try(:resource)
        validate_search_reply(versioned_resource_class('CarePlan'), reply)
        # save_resource_ids_in_bundle(versioned_resource_class('CarePlan'), reply)

      end

      test 'CareTeam resources associated with Patient conform to Argonaut profiles' do

        metadata {
          id '02'
          link 'http://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-careteam.html'
          desc %(
            CareTeam resources associated with Patient conform to Argonaut profiles.
          )
          versions :dstu2
        }
        test_resources_against_profile('CarePlan', Inferno::ValidationUtil::ARGONAUT_URIS[:care_team])
        skip_unless @profiles_encountered.include?(Inferno::ValidationUtil::ARGONAUT_URIS[:care_team]), 'No CareTeams found.'
        assert !@profiles_failed.include?(Inferno::ValidationUtil::ARGONAUT_URIS[:care_team]), "CareTeams failed validation.<br/>#{@profiles_failed[Inferno::ValidationUtil::ARGONAUT_URIS[:care_team]]}"
      end

      test 'All references can be resolved' do

        metadata {
          id '03'
          link 'https://www.hl7.org/fhir/DSTU2/references.html'
          desc %(
            All references in the CareTeam resource should be resolveable.
          )
          versions :dstu2
        }

        skip_if_not_supported(:CareTeam, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        validate_reference_resolutions(@careteam)

      end

    end

  end
end
