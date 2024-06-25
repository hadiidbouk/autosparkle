# frozen_string_literal: true

require 'nokogiri'
require_relative '../environment/environment'
require_relative 'puts_helpers'
require_relative 'version_helpers'

# AppcastXML module to generate the appcast XML file and items
module AppcastXML
  def self.generate_appcast_xml(ed_signature_fragment, deployed_appcast_xml)
    if deployed_appcast_xml
      append_item_to_existing_appcast(ed_signature_fragment, deployed_appcast_xml)
    else
      puts_if_verbose 'Creating a new appcast file...'
      <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"  xmlns:dc="http://purl.org/dc/elements/1.1/">
        	<channel>
        		<title>Changelog</title>
        		<description>Most recent changes with links to updates.</description>
        		<language>en</language>
        		#{generate_appcast_item(ed_signature_fragment)}
        	</channel>
        </rss>
      XML
    end
  end

  def self.append_item_to_existing_appcast(ed_signature_fragment, deployed_appcast_xml)
    puts_if_verbose 'Appending the new item to the existing appcast file...'

    doc = Nokogiri::XML(deployed_appcast_xml)

    new_item_xml = generate_appcast_item(ed_signature_fragment)
    new_item_doc = Nokogiri::XML(new_item_xml)
    new_item = new_item_doc.root

    channel = doc.at_xpath('//channel')
    channel.add_child(new_item)

    doc.to_xml
  end

  def self.generate_appcast_item(ed_signature_fragment)
    date = Time.now.strftime('%a %b %d %H:%M:%S %Z %Y')
    pkg_url = "#{Env.variables.marketing_version}/#{Env.variables.app_display_name}.dmg"
    <<~XML
      <item>
      	<title>#{Env.variables.sparkle_update_title}</title>
      	<link>#{Env.variables.website_url}</link>
      	<sparkle:version>#{Env.variables.current_project_version}</sparkle:version>
      	<sparkle:shortVersionString>#{Env.variables.marketing_version}</sparkle:shortVersionString>
      	<description>
      		<![CDATA[
      		#{Env.variables.sparkle_release_notes}
      		]]>
      	</description>
      	<pubDate>#{date}</pubDate>
      	<enclosure url="#{pkg_url}" type="application/octet-stream" #{ed_signature_fragment} />
      	<sparkle:minimumSystemVersion>#{Env.variables.minimum_macos_version}</sparkle:minimumSystemVersion>
      </item>
    XML
  end

  def self.retreive_versions(deployed_appcast_xml)
    return ['1.0.0', '1'] unless deployed_appcast_xml

    doc = Nokogiri::XML(deployed_appcast_xml)
    [marketing_version(doc), current_project_version(doc)]
  end

  def self.marketing_version(doc)
    method_name = Env.variables.sparkle_bump_version_method
    raise "Unsupported bump method name '#{method_name}'" unless %w[minor patch major same].include?(method_name)

    # bump the marketing version from @variables.sparkle_bump_version_method
    short_version_strings = doc.xpath('//item/sparkle:shortVersionString', 'sparkle' => 'http://www.andymatuschak.org/xml-namespaces/sparkle')
    latest_semantic_version = short_version_strings.map { |s| Gem::Version.new(s.text) }.max
    method_name == 'same' ? latest_semantic_version.to_s : Version.bump(latest_semantic_version, method_name)
  end

  def self.current_project_version(doc)
    # find the latest versions in the item tag for sparkle:version child
    versions = doc.xpath('//item/sparkle:version', 'sparkle' => 'http://www.andymatuschak.org/xml-namespaces/sparkle')
                  .map { |s| s.text.to_i }
    latest_version = versions.max + 1
    latest_version.to_s
  end
end
