# Patch bogus SSL_CONNECT error in retrieve_data
# via KarateCode[https://github.com/KarateCode] (Michael Schneider)
#
require 'openssl'
module OpenSSL
  module SSL
    remove_const :VERIFY_PEER
  end
end
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
#
#

module Yieldmanager
  # This is the data object for all reportware requests.
  #
  # The #pull method is typically called by Yieldmanager::Client#pull_report.
  #
  # Data is returned as an array that can be accessed either by index
  # or by column name:
  #
  #   report.headers # => ['advertiser_name','seller_imps']
  #   report.data[0][0] # => "Bob's Ads"
  #   report.data[0].by_name('advertiser_name') # => "Bob's Ads"
  #   report.data[0].by_name(:advertiser_name) # => "Bob's Ads"
  #
  # Column order is stored in the *headers* array.
  class Report
    attr_accessor :headers, :data

    def initialize
      @headers = []
      @data = []
    end

    def pull token, report, xml
      report_token = request_report_token token, report, xml
      report_url = retrieve_report_url token, report, report_token
      retrieve_data report_url
    end

    def add_row row_data
      row = ReportRow.new(self)
      row_data.each { |ele| row << ele }
      data << row
    end

    def to_hashes
      hashes = []
      data.each do |row|
        row_hash = {}
        row.each_with_index do |ele,idx|
          row_hash[headers[idx]] = ele
        end
        hashes << row_hash
      end
      hashes
    end

    def pause
      sleep(5)
    end

private

    def request_report_token token, report, xml
      report.requestViaXML(token,xml)
    end

    def retrieve_report_url token, report, report_token
      report_url = nil
      60.times do |secs| # Poll until report ready
        report_url = report.status(token,report_token)
        break if report_url
        pause
      end
      report_url
    end

    def retrieve_data url
      retries = 5
      doc = nil
      while (doc == nil && retries > 0) do
        begin
          doc = parse_data(url)
        rescue Exception
          retries = retries - 1
          pause
        end
      end
      raise "Failed pulling report data from #{url}" unless doc

      (doc.css "HEADER COLUMN").each { |col| headers << col.inner_html }

      (doc.css "ROW").each_with_index do |row_elems,idx|
        row = ReportRow.new(self)
        (row_elems.css "COLUMN").each do |col|
          row << col.inner_html
        end
        data << row
      end
    end

    def parse_data url
      Nokogiri::XML(open(url))
    end

    class ReportRow < Array
      def initialize report
        @report = report
      end

      def by_name name
        idx = @report.headers.index(name.to_s)
        raise ArgumentError.new("Column not found: '#{name}'") if idx.nil?
        at(idx)
      end
    end
  end

end
