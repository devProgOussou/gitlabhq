module Gitlab
  module BitbucketImport
    class Importer
      LABELS = [{ title: 'bug', color: '#FF0000' },
                { title: 'enhancement', color: '#428BCA' },
                { title: 'proposal', color: '#69D100' },
                { title: 'task', color: '#7F8C8D' }].freeze

      attr_reader :project, :client, :errors

      def initialize(project)
        @project = project
        @client = Bitbucket::Client.new(project.import_data.credentials)
        @formatter = Gitlab::ImportFormatter.new
        @labels = {}
        @errors = []
      end

      def execute
        import_issues
        import_pull_requests
        handle_errors

        true
      end

      private

      def handle_errors
        return unless errors.any?
        project.update_column(:import_error, {
          message: 'The remote data could not be fully imported.',
          errors: errors
        }.to_json)
      end

      def gitlab_user_id(project, username)
        if username
          user = find_user(username)
          (user && user.id) || project.creator_id
        else
          project.creator_id
        end
      end

      def find_user(username)
        User.joins(:identities).find_by("identities.extern_uid = ? AND identities.provider = 'bitbucket'", username)
      end

      def existing_gitlab_user?(username)
        username && find_user(username)
      end

      def repo
        @repo ||= client.repo(project.import_source)
      end

      def import_issues
        return unless repo.issues_enabled?

        create_labels

        client.issues(repo).each do |issue|
          begin
            description = ''
            description += @formatter.author_line(issue.author) unless existing_gitlab_user?(issue.author)
            description += issue.description

            label_name = issue.kind
            milestone = issue.milestone ? project.milestones.find_or_create_by(title: issue.milestone) : nil

            issue = project.issues.create!(
              iid: issue.iid,
              title: issue.title,
              description: description,
              state: issue.state,
              author_id: gitlab_user_id(project, issue.author),
              milestone: milestone,
              created_at: issue.created_at,
              updated_at: issue.updated_at
            )
          rescue StandardError => e
            errors << { type: :issue, iid: issue.iid, errors: e.message }
          end

          issue.labels << @labels[label_name]

          if issue.persisted?
            client.issue_comments(repo, issue.iid).each do |comment|
              # The note can be blank for issue service messages like "Changed title: ..."
              # We would like to import those comments as well but there is no any
              # specific parameter that would allow to process them, it's just an empty comment.
              # To prevent our importer from just crashing or from creating useless empty comments
              # we do this check.
              next unless comment.note.present?

              note = ''
              note += @formatter.author_line(comment.author) unless existing_gitlab_user?(comment.author)
              note += comment.note

              begin
                issue.notes.create!(
                  project: project,
                  note: note,
                  author_id: gitlab_user_id(project, comment.author),
                  created_at: comment.created_at,
                  updated_at: comment.updated_at
                )
              rescue StandardError => e
                errors << { type: :issue_comment, iid: issue.iid, errors: e.message }
              end
            end
          end
        end
      end

      def create_labels
        LABELS.each do |label|
          @labels[label[:title]] = project.labels.create!(label)
        end
      end

      def import_pull_requests
        pull_requests = client.pull_requests(repo)

        pull_requests.each do |pull_request|
          begin
            description = ''
            description += @formatter.author_line(pull_request.author) unless existing_gitlab_user?(pull_request.author)
            description += pull_request.description

            merge_request = project.merge_requests.create(
              iid: pull_request.iid,
              title: pull_request.title,
              description: description,
              source_project: project,
              source_branch: pull_request.source_branch_name,
              source_branch_sha: pull_request.source_branch_sha,
              target_project: project,
              target_branch: pull_request.target_branch_name,
              target_branch_sha: pull_request.target_branch_sha,
              state: pull_request.state,
              author_id: gitlab_user_id(project, pull_request.author),
              assignee_id: nil,
              created_at: pull_request.created_at,
              updated_at: pull_request.updated_at
            )

            import_pull_request_comments(pull_request, merge_request) if merge_request.persisted?
          rescue StandardError => e
            errors << { type: :pull_request, iid: pull_request.iid, errors: e.message }
          end
        end
      end

      def import_pull_request_comments(pull_request, merge_request)
        comments = client.pull_request_comments(repo, pull_request.iid)

        inline_comments, pr_comments = comments.partition(&:inline?)

        import_inline_comments(inline_comments, pull_request, merge_request)
        import_standalone_pr_comments(pr_comments, merge_request)
      end

      def import_inline_comments(inline_comments, pull_request, merge_request)
        line_code_map = {}

        children, parents = inline_comments.partition(&:has_parent?)

        # The Bitbucket API returns threaded replies as parent-child
        # relationships. We assume that the child can appear in any order in
        # the JSON.
        parents.each do |comment|
          line_code_map[comment.iid] = generate_line_code(comment)
        end

        children.each do |comment|
          line_code_map[comment.iid] = line_code_map.fetch(comment.parent_id, nil)
        end

        inline_comments.each do |comment|
          begin
            attributes = pull_request_comment_attributes(comment)
            attributes.merge!(
              position: build_position(merge_request, comment),
              line_code: line_code_map.fetch(comment.iid),
              type: 'DiffNote')

            merge_request.notes.create!(attributes)
          rescue StandardError => e
            errors << { type: :pull_request, iid: comment.iid, errors: e.message }
          end
        end
      end

      def build_position(merge_request, pr_comment)
        params = {
          diff_refs: merge_request.diff_refs,
          old_path: pr_comment.file_path,
          new_path: pr_comment.file_path,
          old_line: pr_comment.old_pos,
          new_line: pr_comment.new_pos
        }

        Gitlab::Diff::Position.new(params)
      end

      def import_standalone_pr_comments(pr_comments, merge_request)
        pr_comments.each do |comment|
          begin
            merge_request.notes.create!(pull_request_comment_attributes(comment))
          rescue StandardError => e
            errors << { type: :pull_request, iid: comment.iid, errors: e.message }
          end
        end
      end

      def generate_line_code(pr_comment)
        Gitlab::Diff::LineCode.generate(pr_comment.file_path, pr_comment.new_pos, pr_comment.old_pos)
      end

      def pull_request_comment_attributes(comment)
        {
          project: project,
          note: comment.note,
          author_id: gitlab_user_id(project, comment.author),
          created_at: comment.created_at,
          updated_at: comment.updated_at
        }
      end
    end
  end
end
