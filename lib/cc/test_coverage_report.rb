module CC
  class TestCoverageReport
    NoTestReportFound = Class.new(StandardError)

    def initialize(repo_slug:, cc_access_token:, github_access_token:, days_since:)
      @repo_slug = repo_slug
      @cc_access_token = cc_access_token
      @github_access_token = github_access_token
      @days_since = days_since
    end

    def run
      puts "Running report repo=#{repo_slug} id=#{cc_repo.fetch('id')} from=#{from_commit.sha[0,6]} to=#{commits.first.sha[0,6]}"

      collect_added_files
      collect_line_numbers
      apply_coverage_info

      print
    end

    def print
      if report.empty?
        puts "No added lines with test covearge information found"
      else
        format="%40s\t%10s\n"
        printf(format, "Path", "Added Lines Covered")

        lines = covered = 0
        report.each do |path, additions|
          path_added_lines = additions.count
          path_covered_lines = additions.select { |addition| addition[:covered] }.count

          lines += path_added_lines
          covered += path_covered_lines

          printf(format,path.split("/").last, "#{path_covered_lines}/#{path_added_lines} - #{((path_covered_lines.to_f / path_added_lines) * 100).round(2)}%")
        end

        puts "\n#{covered}/#{lines} - #{((covered.to_f / lines) * 100).round(2)}% added lines covered"
      end
    end

    private

    attr_reader :repo_slug, :cc_access_token, :github_access_token, :days_since

    def report
      @report ||= {}
    end

    def collect_added_files
      commit_comparison.files.select { |file| file.additions > 0 }.each do |file|
        if (patch = file.patch)
          lines = patch.split("\n")
          added = lines.select { |string| string.start_with?("+") }
          report[file.filename] = added.map { |string| { body: string.sub(/^\+/, "") } }
        end
      end
    end

    def collect_line_numbers
      report.each do |path, additions|
        begin
          contents = github_client.contents(repo_slug, path: path, ref: commits.first.sha)
          contents_decoded = Base64.decode64(contents.content).split("\n")

          additions.each do |addition|
            addition[:line] = contents_decoded.index(addition[:body])
          end
        rescue Octokit::NotFound
          report.delete(path)
        end
      end
    end

    def apply_coverage_info
      report.each do |path, additions|
        if (test_file_report = test_file_reports.find { |test_file_report| path == test_file_report.fetch("attributes").fetch("path") })
          additions.each do |addition|
            coverage = test_file_report.fetch("attributes").fetch("coverage")[addition[:line]]
            if !coverage.nil? && coverage > 0
              addition[:covered] = true
            else
              addition[:covered] = false
            end
          end
        else
          report.delete(path)
        end
      end
    end

    def test_report(index = 0)
      @test_report ||= begin
        sha = commits.fetch(index).sha
        puts "Fetching test report sha=#{sha}"

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

    def commit_comparison
      @commit_comparison ||= begin 
        puts "Comparing on GitHub from=#{from_commit.sha} to=#{commits.first.sha}"
        comparison = github_client.compare(repo_slug, from_commit.sha, commits.first.sha)
        puts "#{comparison.total_commits} commits in comparison"
        comparison
      end
    end

    def test_file_reports
      @test_file_reports ||= begin
        file_paths = commit_comparison.files
          .map(&:filename)
          .select { |filename| filename.end_with?(*%w[js rb py php]) }

        params = { page: { size: commit_comparison.files.count }, filter: { path: { "$in" =>  file_paths } } }

        response = cc_client.get("/v1/repos/#{cc_repo.fetch("id")}/test_reports/#{test_report.fetch("id")}/test_file_reports") do |request|
          request.params = params
        end

        JSON.parse(response.body).fetch("data")
      end
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
