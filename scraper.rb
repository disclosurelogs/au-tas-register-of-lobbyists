require 'scraperwiki'
ScraperWiki.sqliteexecute('DROP TABLE IF EXISTS swvariables');
require 'open-uri'
require 'yaml'
class Array
  def to_yaml_style
    :inline
  end
end

html = ScraperWiki.scrape("http://lobbyists.dpac.tas.gov.au/lobbyist_register")

# Next we use Nokogiri to extract the values from the HTML source.

require 'nokogiri'
page = Nokogiri::HTML(html)
baseurl = "http://lobbyists.dpac.tas.gov.au/lobbyist_register"
urls = page.search(".//table[@id = 'lobbyistsTable']//a").map { |a| a.attributes['href'] }

urls.map do |url|

  url = "#{url}"

  puts "Downloading #{url}"
  begin
    lobbypage = Nokogiri::HTML(ScraperWiki.scrape(url))

    #thanks http://ponderer.org/download/xpath/ and http://www.zvon.org/xxl/XPathTutorial/Output/
    employees = []
    clients = []
    owners = []
    names = []
    lobbyist_firm = {}

    companyABN=lobbypage.xpath("//tr/td/strong[text() = 'A.B.N:']/ancestor::td/following-sibling::node()/text()")
    businessName=lobbypage.xpath("//tr/td/strong[text() = 'Business entity name:']/ancestor::td/following-sibling::node()/text()")
    tradingName=lobbypage.xpath("//tr/td/strong[text() = 'Trading name:']/ancestor::td/following-sibling::node()/text()")
    businessName= businessName.to_s.gsub(/\302\240/, '').strip
    tradingName= tradingName.to_s.gsub(/\302\240/, '').strip
    companyABN= companyABN.to_s.strip.delete(' ').delete('.').to_s
    lobbyist_firm["business_name"] = businessName.to_s
    lobbyist_firm["trading_name"] = tradingName.to_s
    lobbyist_firm["abn"] = companyABN.to_s

    employeeNames = lobbypage.xpath("//strong[text() = 'Names and positions:'][1]/ancestor::td/following-sibling::node()/text()")
    employeeNames[0].to_s.split(';').each do |employee|
      employeeName = employee.gsub(/\u00a0/, '').gsub("  ", " ").strip
      if employeeName.empty? == false
        employees << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => employeeName}
      end
    end

    names = lobbypage.xpath("//strong[text() = 'Name:'][1]/ancestor::td/following-sibling::node()/text()")
    names[0].to_s.split(';').each do |client|
      clientName = client.gsub(/\u00a0/, '').strip
      if clientName.empty? == false
        clients << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => clientName }
      end
    end

    names[1].to_s.split(';').each do |owner|
      ownerName = owner.gsub(/\u00a0/, '').strip
      if ownerName.empty? == false and ownerName.class != 'binary'
        owners << { "lobbyist_firm_name" => lobbyist_firm["business_name"],"lobbyist_firm_abn" => lobbyist_firm["abn"], "name" => ownerName }
      end
    end

    lobbyist_firm["last_updated"] = lobbypage.xpath("//div[@id='TG-footer']/p[3]/text()[2]").to_s.gsub('This page was last modified on', '')

    ScraperWiki.save(unique_keys=["name", "lobbyist_firm_abn"], data=employees, table_name="lobbyists")
    ScraperWiki.save(unique_keys=["name", "lobbyist_firm_abn"], data=clients, table_name="lobbyist_clients")
    ScraperWiki.save(unique_keys=["name", "lobbyist_firm_abn"], data=owners, table_name="lobbyist_firm_owners")
    ScraperWiki.save(unique_keys=["business_name", "abn"], data=lobbyist_firm, table_name="lobbyist_firms")
  rescue Timeout::Error => e
    print "Timeout on #{url}"
  end
end
