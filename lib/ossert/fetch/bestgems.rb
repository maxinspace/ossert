module Ossert
  module Fetch
    class BestgemsBase
      def self.process_page(page = nil)
        doc = Nokogiri::HTML(open("http://bestgems.org/#{endpoint}#{page ? "?page=#{page}" : '' }"))
        doc.css("table").xpath('//tr//td').each_slice(4) do |rank, downloads, name, _|
          rank = rank.text.delete(',').to_i
          downloads = downloads.text.delete(',').to_i
          yield(rank, downloads, name.text)
        end
      end
    end

    class BestgemsDailyStat < BestgemsBase
      def self.endpoint
        :daily
      end
    end

    class BestgemsTotalStat < BestgemsBase
      def self.endpoint
        :total
      end
    end

    class Bestgems
      attr_reader :client, :project

      extend Forwardable
      def_delegators :project, :agility, :community, :meta

      def initialize(project)
        @client = SimpleClient.new("http://bestgems.org/api/v1/")
        @project = project
      end

      def total_downloads
        client.get("gems/#{project.rubygems_alias}/total_downloads.json")
      end

      def daily_downloads
        client.get("gems/#{project.rubygems_alias}/daily_downloads.json")
      end

      def total_ranking
        client.get("gems/#{project.rubygems_alias}/total_ranking.json")
      end

      def daily_ranking
        client.get("gems/#{project.rubygems_alias}/daily_ranking.json")
      end

      def process
        downloads_till_now = nil
        total_downloads.each do |total|
          downloads_till_now = total unless downloads_till_now
          downloads_saved = community.quarters[total['date']].total_downloads.to_i
          community.quarters[total['date']].total_downloads = [downloads_saved, total['total_downloads']].max
        end
        community.total.total_downloads = downloads_till_now['total_downloads']

        daily_downloads.each do |daily|
          downloads_saved = community.quarters[daily['date']].delta_downloads.to_i
          community.quarters[daily['date']].delta_downloads = downloads_saved + daily['daily_downloads']
        end

        prev_downloads_delta = 0
        community.quarters.each_sorted do |start_date, stat|
          prev_downloads_delta  = stat.delta_downloads.to_i - prev_downloads_delta
          community.quarters[start_date].download_divergence = divergence(
            prev_downloads_delta, downloads_till_now['total_downloads']
          )
        end
      end

      private

      def divergence(delta, total)
        (delta.to_f / total.to_f * 100.0).round(2)
      end
    end
  end
end
