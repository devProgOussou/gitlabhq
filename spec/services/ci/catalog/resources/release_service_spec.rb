# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Catalog::Resources::ReleaseService, feature_category: :pipeline_composition do
  describe '#execute' do
    context 'with a valid catalog resource and release' do
      it 'validates the catalog resource and creates a version' do
        project = create(:project, :catalog_resource_with_components)
        catalog_resource = create(:ci_catalog_resource, project: project)
        release = create(:release, project: project, sha: project.repository.root_ref_sha)

        response = described_class.new(release).execute

        version = Ci::Catalog::Resources::Version.last

        expect(response).to be_success
        expect(version.release).to eq(release)
        expect(version.catalog_resource).to eq(catalog_resource)
        expect(version.catalog_resource.project).to eq(project)
      end
    end

    context 'when the validation of the catalog resource fails' do
      it 'returns an error and does not create a version' do
        project = create(:project, :repository)
        create(:ci_catalog_resource, project: project)
        release = create(:release, project: project, sha: project.repository.root_ref_sha)

        response = described_class.new(release).execute

        expect(Ci::Catalog::Resources::Version.count).to be(0)
        expect(response).to be_error
        expect(response.message).to eq('Project must have a description, Project must contain components')
      end
    end

    context 'when the creation of a version fails' do
      it 'returns an error and does not create a version' do
        project =
          create(
            :project, :custom_repo,
            description: 'Component project',
            files: {
              'templates/secret-detection.yml' => 'image: agent: coop',
              'README.md' => 'Read me'
            }
          )
        create(:ci_catalog_resource, project: project)
        release = create(:release, project: project, sha: project.repository.root_ref_sha)

        response = described_class.new(release).execute

        expect(Ci::Catalog::Resources::Version.count).to be(0)
        expect(response).to be_error
        expect(response.message).to include('mapping values are not allowed in this context')
      end
    end
  end
end
