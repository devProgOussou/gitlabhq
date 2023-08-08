# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::FileSizeCheck::HookEnvironmentAwareAnyOversizedBlobs, feature_category: :source_code_management do
  let_it_be(:project) { create(:project, :small_repo) }
  let(:file_size_limit) { 1 }
  let(:any_quarantined_blobs) do
    described_class.new(
      project: project,
      changes: changes,
      file_size_limit_megabytes: file_size_limit)
  end

  let(:changes) { [{ newrev: 'master' }] }

  describe '#find' do
    subject { any_quarantined_blobs.find }

    let(:stubbed_result) { 'stubbed' }

    it 'returns the result from AnyOversizedBlobs' do
      expect_next_instance_of(Gitlab::Checks::FileSizeCheck::AnyOversizedBlobs) do |instance|
        expect(instance).to receive(:find).and_return(stubbed_result)
      end

      expect(subject).to eq(stubbed_result)
    end

    context 'with hook env' do
      context 'with hook environment' do
        let(:git_env) do
          {
            'GIT_OBJECT_DIRECTORY_RELATIVE' => "objects",
            'GIT_ALTERNATE_OBJECT_DIRECTORIES_RELATIVE' => ['/dir/one', '/dir/two']
          }
        end

        before do
          allow(Gitlab::Git::HookEnv).to receive(:all).with(project.repository.gl_repository).and_return(git_env)
        end

        it 'returns an emtpy array' do
          expect(subject).to eq([])
        end

        context 'when the file is over the limit' do
          let(:file_size_limit) { 0 }

          it 'returns an array with the blobs that are over the limit' do
            expect(subject.size).to eq(1)
            expect(subject.first).to be_kind_of(Gitlab::Git::Blob)
          end
        end
      end
    end
  end
end
