# frozen_string_literal: true

module CC
  class TestCoverageReport
    File = Struct.new(:path, :lines)
    Line = Struct.new(:number, :covered)
    NoTestReportFound = Class.new(StandardError)

    def initialize(repo_slug:, cc_access_token:, github_access_token:, days_since:)
      @repo_slug = repo_slug
      @cc_access_token = cc_access_token
      @github_access_token = github_access_token
      @days_since = days_since
    end

    def find_test_report(path)
      test_file_reports.find do |report|
        path == report.fetch("attributes").fetch("path")
      end
    end

    def run
      files = patches.each_with_object([]) do |patch, memo|
        if patch.changed_lines.any? && (test_file_report = find_test_report(patch.file))
          coverage = test_file_report.fetch("attributes").fetch("coverage")

          lines = patch.changed_line_numbers.map do |line_number|
            covered = !coverage[line_number - 1].nil? && coverage[line_number - 1].nonzero?
            Line.new(line_number, covered)
          end

          memo << File.new(patch.file, lines)
        end
      end

      print_report(files)
    end

    def print_report(files)
      max_path_length = files.map(&:path).map(&:length).max
      format = "%#{max_path_length}s\t%d/%d %.2f%\n"

      files.each do |file|
        printf(format, file.path, file.lines.count(&:covered), file.lines.count, covered_lines_percentage(file.lines))
      end

      all_lines = files.map(&:lines).flatten
      printf(format, "Total", all_lines.count(&:covered), all_lines.count, covered_lines_percentage(all_lines))
    end

    private

    attr_reader :repo_slug, :cc_access_token, :github_access_token, :days_since

    def test_report(index = 0)
      @test_report ||= begin
        sha = commits.fetch(index).sha

        response = cc_client.get("/v1/repos/#{cc_repo.fetch("id")}/test_reports") do |request|
          request.params = { filter: { commit_sha: sha } }
        end

        JSON.parse(response.body).fetch("data").first or raise NoTestReportFound
      end
    rescue NoTestReportFound => ex
      if index < 3
        test_report(index + 1)
      else
        raise ex
      end
    end

    def test_file_report(file_path)
      endpoint = "/v1/repos/#{cc_repo.fetch("id")}/test_reports/#{test_report.fetch("id")}/test_file_reports"

      response = cc_client.get(endpoint) do |request|
        request.params = { filter: { path: file_path } }
      end

      JSON.parse(response.body).fetch("data").first
    end

    def from_commit
      @from_commit ||= begin
        github_client.commits(repo_slug, until: Date.today - days_since).first
      end
    end

    def commits
      @commits ||= github_client.commits(repo_slug)
    end

    def cc_repo
      @cc_repo ||= begin
        response = cc_client.get("/v1/repos") do |request|
          request.params["github_slug"] = repo_slug
        end

        JSON.parse(response.body).fetch("data").first or raise "CC repo not found"
      end
    end

    def eligible_file_paths
      @eligible_file_paths ||=
        patches.
        map(&:file).
        select { |filename| filename.end_with?("js", "rb", "py", "php") }.
        reject { |filename| filename.end_with?("_spec.rb") }
    end

    def test_file_reports
      @test_file_reports ||= begin
        reports = []

        eligible_file_paths.each_slice(20) do |paths|
          params = { page: { size: paths.count }, filter: { path: { "$in": paths } } }
          reports << fetch_test_file_reports(params)
        end

        reports.flatten
      end
    end

    def fetch_test_file_reports(params)
      endpoint = "/v1/repos/#{cc_repo.fetch("id")}/test_reports/#{test_report.fetch("id")}/test_file_reports"
      response = cc_client.get(endpoint) { |request| request.params = params }

      JSON.parse(response.body).fetch("data")
    end

    def covered_lines_percentage(lines)
      ((lines.count(&:covered).to_f / lines.count) * 100).round(2)
    end

    def patches
      @patches ||= GitDiffParser.parse(diff)
    end

    def diff
      @diff ||= github_client.compare(
        repo_slug,
        from_commit.sha,
        commits.first.sha,
        accept: "application/vnd.github.diff",
      )
    end

    def github_client
      @github_client ||= Octokit::Client.new(access_token: github_access_token)
    end

    def cc_client
      @cc_client ||= Faraday.new(
        url: "https://api.codeclimate.com",
        headers: {
          "Accept": "application/vnd.api+json",
          "Authorization": "Token token=#{cc_access_token}",
        },
      )
    end
  end
end
