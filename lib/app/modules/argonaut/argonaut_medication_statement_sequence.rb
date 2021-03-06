# frozen_string_literal: true

module Inferno
  module Sequence
    class ArgonautMedicationStatementSequence < SequenceBase
      title 'Medication Statement'

      description 'Verify that MedicationStatement resources on the FHIR server follow the Argonaut Data Query Implementation Guide'

      test_id_prefix 'ARMS'

      requires :token, :patient_id
      conformance_supports :MedicationStatement

      details %(
        # Background
        The #{title} Sequence tests the [#{title}](https://www.hl7.org/fhir/DSTU2/medicationstatement.html)
        resource provided by a FHIR server.  The #{title} provided must be consistent with the [#{title}
        Argonaut Profile](https://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-medicationstatement.html).

        )
      @resources_found = false

      test 'Server rejects MedicationStatement search without authorization' do
        metadata do
          id '01'
          link 'https://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-medicationstatement.html'
          desc %(
            A MedicationStatement search does not work without proper authorization.
          )
          versions :dstu2
        end

        skip_if_not_supported(:MedicationStatement, [:search, :read])

        @client.set_no_auth
        skip 'Could not verify this functionality when bearer token is not set' if @instance.token.blank?

        reply = get_resource_by_params(versioned_resource_class('MedicationStatement'), {patient: @instance.patient_id})
        @client.set_bearer_token(@instance.token)
        assert_response_unauthorized reply
      end

      test 'Server returns expected results from MedicationStatement search by patient' do
        metadata do
          id '02'
          link 'https://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-medicationstatement.html'
          desc %(
            A server is capable of returning a patient's medications.
          )
          versions :dstu2
        end

        skip_if_not_supported(:MedicationStatement, [:search, :read])

        reply = get_resource_by_params(versioned_resource_class('MedicationStatement'), {patient: @instance.patient_id})
        assert_response_ok(reply)
        assert_bundle_response(reply)

        resource_count = reply.try(:resource).try(:entry).try(:length) || 0
        if resource_count > 0
          @resources_found = true
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        @medication_statements = reply&.resource&.entry&.map do |med_statement|
          med_statement&.resource
        end
        validate_search_reply(versioned_resource_class('MedicationStatement'), reply)
        save_resource_ids_in_bundle(versioned_resource_class('MedicationStatement'), reply)
      end

      test 'MedicationStatement read resource supported' do
        metadata do
          id '03'
          link 'https://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-medicationstatement.html'
          desc %(
            All servers SHALL make available the read interactions for the Argonaut Profiles the server chooses to support.
          )
          versions :dstu2
        end

        skip_if_not_supported(:MedicationStatement, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        @medication_statements.each do |medication_statement|
          validate_read_reply(medication_statement, versioned_resource_class('MedicationStatement'))
        end

      end

      test 'MedicationStatement history resource supported' do
        metadata do
          id '04'
          link 'https://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-medicationstatement.html'
          optional
          desc %(
            All servers SHOULD make available the vread and history-instance interactions for the Argonaut Profiles the server chooses to support.
          )
          versions :dstu2
        end

        skip_if_not_supported(:MedicationStatement, [:history])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        @medication_statements.each do |medication_statement|
          validate_history_reply(medication_statement, versioned_resource_class('MedicationStatement'))
        end

      end

      test 'MedicationStatement vread resource supported' do
        metadata do
          id '05'
          link 'https://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-medicationstatement.html'
          optional
          desc %(
            All servers SHOULD make available the vread and history-instance interactions for the Argonaut Profiles the server chooses to support.
          )
          versions :dstu2
        end

        skip_if_not_supported(:MedicationStatement, [:vread])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        @medication_statements.each do |medication_statement|
          validate_vread_reply(medication_statement, versioned_resource_class('MedicationStatement'))
        end

      end

      test 'MedicationStatement resources associated with Patient conform to Argonaut profiles' do
        metadata do
          id '06'
          link 'https://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-medicationstatement.html'
          desc %(
            MedicationStatement resources associated with Patient conform to Argonaut profiles.
          )
          versions :dstu2
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' if @no_resources_found

        test_resources_against_profile('MedicationStatement')
      end

      test 'Referenced Medications support read interactions' do
        metadata do
          id '07'
          link 'https://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-medication.html'
          versions :dstu2
          desc %(
            Medication resources must conform to the Argonaut profile
               )
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' if @no_resources_found

        @medication_references = @medication_statements&.select do |medication_statement|
          !medication_statement.medicationReference.nil?
        end&.map do |ref|
          ref.medicationReference
        end

        pass 'Test passes because medication resource references are not used in any medication statements.' if @medication_references.nil? || @medication_references.empty?

        not_contained_refs = @medication_references&.select {|ref| !ref.contained?}
      end

      test 'All references can be resolved' do

        metadata {
          id '08'
          link 'https://www.hl7.org/fhir/DSTU2/references.html'
          desc %(
            All references in the MedicationStatement resource should be resolveable.
          )
          versions :dstu2
        }

        skip_if_not_supported(:MedicationStatement, [:search, :read])
        skip 'No resources appear to be available for this patient. Please use patients with more information.' unless @resources_found

        @medication_statements.each do |medication_statement|
          validate_reference_resolutions(medication_statement)
        end


      end

      test 'Referenced Medications conform to the Argonaut profile' do
        metadata do
          id '09'
          link 'https://www.fhir.org/guides/argonaut/r2/StructureDefinition-argo-medication.html'
          versions :dstu2
          desc %(
            Medication resources must conform to the Argonaut profile
               )
        end

        skip 'No resources appear to be available for this patient. Please use patients with more information.' if @no_resources_found

        pass 'Test passes because medication resource references are not used in any medication statements.' if @medication_references.nil? || @medication_references.empty?

        @medication_references&.each do |medication|
          medication_resource = medication.read
          check_resource_against_profile(medication_resource, 'Medication')
        end
      end
    end
  end
end
