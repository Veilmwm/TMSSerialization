class OaiController < ApplicationController
  before_action :set_response_format

  REPOSITORY_NAME = "YCBA TMS LIDO OAI-PMH"
  BASE_URL = "http://localhost:3000/oai"
  ADMIN_EMAIL = "admin@example.com"
  EARLIEST_DATESTAMP = "2020-01-01T00:00:00Z"
  PROTOCOL_VERSION = "2.0"

  SUPPORTED_FORMATS = {
     "lido" => {
       schema: "http://www.lido-schema.org/schema/v1.0/lido-v1.0.xsd",
       namespace: "http://www.lido-schema.org"
     },

  def index
    @verb = params[:verb]
    @request_params = request.query_parameters

    if @verb.nil?
      render_error("badVerb", "Missing verb argument")
      return
    end

    case @verb
    when "Identify"
      identify
    when "ListMetadataFormats"
      list_metadata_formats
    when "ListSets"
      list_sets
    when "ListIdentifiers"
      list_identifiers
    when "ListRecords"
      list_records
    when "GetRecord"
      get_record
    else
      render_error("badVerb", "Illegal verb: #{@verb}")
    end
  end

  private

  def identify
    # Check for illegal arguments
    if has_illegal_arguments?(["verb"])
      render_error("badArgument", "The request includes illegal arguments")
      return
    end

    render xml: build_response { |xml|
      xml.Identify do
        xml.repositoryName REPOSITORY_NAME
        xml.baseURL BASE_URL
        xml.protocolVersion PROTOCOL_VERSION
        xml.adminEmail ADMIN_EMAIL
        xml.earliestDatestamp EARLIEST_DATESTAMP
        xml.deletedRecord "no"
        xml.granularity "YYYY-MM-DDThh:mm:ssZ"
      end
    }
  end

  def list_metadata_formats
    identifier = params[:identifier]

    # Check for illegal arguments
    allowed = ["verb", "identifier"]
    if has_illegal_arguments?(allowed)
      render_error("badArgument", "The request includes illegal arguments")
      return
    end

    # If identifier is provided, check if it exists
    if identifier.present? && !identifier_exists?(identifier)
      render_error("idDoesNotExist", "The value of the identifier argument is unknown or illegal")
      return
    end

    render xml: build_response { |xml|
      xml.ListMetadataFormats do
        SUPPORTED_FORMATS.each do |prefix, format_info|
          xml.metadataFormat do
            xml.metadataPrefix prefix
            xml.schema format_info[:schema]
            xml.metadataNamespace format_info[:namespace]
          end
        end
      end
    }
  end

  def list_sets
    # Check for resumptionToken exclusivity
    if params[:resumptionToken].present? && params.except(:verb, :resumptionToken, :controller, :action).any?
      render_error("badArgument", "resumptionToken cannot be combined with other arguments")
      return
    end

    # Check for illegal arguments
    allowed = ["verb", "resumptionToken"]
    if has_illegal_arguments?(allowed)
      render_error("badArgument", "The request includes illegal arguments")
      return
    end

    # Sample sets
    sets = [
      { spec: "set1", name: "Sample Set 1", description: "This is the first sample set" },
      { spec: "set2", name: "Sample Set 2", description: "This is the second sample set" }
    ]

    render xml: build_response { |xml|
      xml.ListSets do
        sets.each do |set|
          xml.set do
            xml.setSpec set[:spec]
            xml.setName set[:name]
            xml.setDescription do
              xml.tag!("oai_dc:dc",
                "xmlns:oai_dc" => "http://www.openarchives.org/OAI/2.0/oai_dc/",
                "xmlns:dc" => "http://purl.org/dc/elements/1.1/") do
                xml.tag!("dc:description", set[:description])
              end
            end
          end
        end
      end
    }
  end

  def list_identifiers
    # Validate required arguments
    if params[:resumptionToken].blank? && params[:metadataPrefix].blank?
      render_error("badArgument", "Missing required argument: metadataPrefix")
      return
    end

    # Check for resumptionToken exclusivity
    if params[:resumptionToken].present? && params.except(:verb, :resumptionToken, :controller, :action).any?
      render_error("badArgument", "resumptionToken cannot be combined with other arguments")
      return
    end

    # Check for illegal arguments
    allowed = ["verb", "metadataPrefix", "from", "until", "set", "resumptionToken"]
    if has_illegal_arguments?(allowed)
      render_error("badArgument", "The request includes illegal arguments")
      return
    end

    # Validate metadataPrefix
    metadata_prefix = params[:metadataPrefix]
    if metadata_prefix.present? && !SUPPORTED_FORMATS.key?(metadata_prefix)
      render_error("cannotDisseminateFormat", "The metadata format identified by the value given for the metadataPrefix argument is not supported")
      return
    end

    # Validate date arguments
    if params[:from].present? && !valid_datestamp?(params[:from])
      render_error("badArgument", "Invalid from date format")
      return
    end

    if params[:until].present? && !valid_datestamp?(params[:until])
      render_error("badArgument", "Invalid until date format")
      return
    end

    # Sample records
    records = sample_records

    render xml: build_response { |xml|
      xml.ListIdentifiers do
        records.each do |record|
          xml.header do
            xml.identifier record[:identifier]
            xml.datestamp record[:datestamp]
            xml.setSpec record[:set_spec] if record[:set_spec].present?
          end
        end
      end
    }
  end

  def list_records
    # Validate required arguments
    if params[:resumptionToken].blank? && params[:metadataPrefix].blank?
      render_error("badArgument", "Missing required argument: metadataPrefix")
      return
    end

    # Check for resumptionToken exclusivity
    if params[:resumptionToken].present? && params.except(:verb, :resumptionToken, :controller, :action).any?
      render_error("badArgument", "resumptionToken cannot be combined with other arguments")
      return
    end

    # Check for illegal arguments
    allowed = ["verb", "metadataPrefix", "from", "until", "set", "resumptionToken"]
    if has_illegal_arguments?(allowed)
      render_error("badArgument", "The request includes illegal arguments")
      return
    end

    # Validate metadataPrefix
    metadata_prefix = params[:metadataPrefix]
    if metadata_prefix.present? && !SUPPORTED_FORMATS.key?(metadata_prefix)
      render_error("cannotDisseminateFormat", "The metadata format identified by the value given for the metadataPrefix argument is not supported")
      return
    end

    # Validate date arguments
    if params[:from].present? && !valid_datestamp?(params[:from])
      render_error("badArgument", "Invalid from date format")
      return
    end

    if params[:until].present? && !valid_datestamp?(params[:until])
      render_error("badArgument", "Invalid until date format")
      return
    end

    # Sample records
    records = sample_records

    render xml: build_response { |xml|
      xml.ListRecords do
        records.each do |record|
          xml.record do
            xml.header do
              xml.identifier record[:identifier]
              xml.datestamp record[:datestamp]
              xml.setSpec record[:set_spec] if record[:set_spec].present?
            end
            xml.metadata do
              build_metadata(xml, record, metadata_prefix)
            end
          end
        end
      end
    }
  end

  def get_record
    # Validate required arguments
    if params[:identifier].blank?
      render_error("badArgument", "Missing required argument: identifier")
      return
    end

    if params[:metadataPrefix].blank?
      render_error("badArgument", "Missing required argument: metadataPrefix")
      return
    end

    # Check for illegal arguments
    allowed = ["verb", "identifier", "metadataPrefix"]
    if has_illegal_arguments?(allowed)
      render_error("badArgument", "The request includes illegal arguments")
      return
    end

    identifier = params[:identifier]
    metadata_prefix = params[:metadataPrefix]

    # Validate metadataPrefix
    unless SUPPORTED_FORMATS.key?(metadata_prefix)
      render_error("cannotDisseminateFormat", "The metadata format identified by the value given for the metadataPrefix argument is not supported")
      return
    end

    # Check if identifier exists
    unless identifier_exists?(identifier)
      render_error("idDoesNotExist", "The value of the identifier argument is unknown or illegal")
      return
    end

    # Find the record
    record = find_record(identifier)

    render xml: build_response { |xml|
      xml.GetRecord do
        xml.record do
          xml.header do
            xml.identifier record[:identifier]
            xml.datestamp record[:datestamp]
            xml.setSpec record[:set_spec] if record[:set_spec].present?
          end
          xml.metadata do
            build_metadata(xml, record, metadata_prefix)
          end
        end
      end
    }
  end

  # Helper methods

  def set_response_format
    request.format = :xml
  end

  def build_response
    Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.send(:'OAI-PMH',
        'xmlns' => 'http://www.openarchives.org/OAI/2.0/',
        'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
        'xsi:schemaLocation' => 'http://www.openarchives.org/OAI/2.0/ http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd') do

        xml.responseDate Time.now.utc.iso8601
        xml.request(request.original_url, @request_params.merge(verb: @verb))

        yield(xml)
      end
    end.to_xml
  end

  def render_error(code, message)
    render xml: build_response { |xml|
      xml.error(message, code: code)
    }
  end

  def has_illegal_arguments?(allowed_params)
    actual_params = params.keys - ["controller", "action", "format"]
    (actual_params - allowed_params).any?
  end

  def valid_datestamp?(date_string)
    # OAI-PMH supports two granularities: YYYY-MM-DD and YYYY-MM-DDThh:mm:ssZ
    return true if date_string.match?(/^\d{4}-\d{2}-\d{2}$/)
    return true if date_string.match?(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/)
    false
  end

  def identifier_exists?(identifier)
    # Sample implementation - check against sample records
    sample_records.any? { |r| r[:identifier] == identifier }
  end

  def find_record(identifier)
    # Sample implementation - find in sample records
    sample_records.find { |r| r[:identifier] == identifier }
  end

  def sample_records
    # Sample records for demonstration
    [
      {
        identifier: "oai:example.org:item1",
        datestamp: "2024-01-15T10:30:00Z",
        set_spec: "set1",
        title: "Sample Record 1",
        creator: "John Doe",
        subject: "Sample Subject",
        description: "This is a sample record for testing OAI-PMH implementation",
        publisher: "Example Publisher",
        date: "2024-01-15"
      },
      {
        identifier: "oai:example.org:item2",
        datestamp: "2024-02-20T14:45:00Z",
        set_spec: "set2",
        title: "Sample Record 2",
        creator: "Jane Smith",
        subject: "Another Subject",
        description: "This is another sample record",
        publisher: "Example Publisher",
        date: "2024-02-20"
      }
    ]
  end

  def build_metadata(xml, record, metadata_prefix)
    case metadata_prefix
    when "oai_dc"
      xml.tag!("oai_dc:dc",
        "xmlns:oai_dc" => "http://www.openarchives.org/OAI/2.0/oai_dc/",
        "xmlns:dc" => "http://purl.org/dc/elements/1.1/",
        "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
        "xsi:schemaLocation" => "http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd") do

        xml.tag!("dc:title", record[:title]) if record[:title]
        xml.tag!("dc:creator", record[:creator]) if record[:creator]
        xml.tag!("dc:subject", record[:subject]) if record[:subject]
        xml.tag!("dc:description", record[:description]) if record[:description]
        xml.tag!("dc:publisher", record[:publisher]) if record[:publisher]
        xml.tag!("dc:date", record[:date]) if record[:date]
        xml.tag!("dc:type", "Text")
        xml.tag!("dc:identifier", record[:identifier])
      end
    when "oai_marc"
      # Simplified MARC format
      xml.tag!("oai_marc:record",
        "xmlns:oai_marc" => "http://www.openarchives.org/OAI/2.0/oai_marc/",
        "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
        "xsi:schemaLocation" => "http://www.openarchives.org/OAI/2.0/oai_marc/ http://www.openarchives.org/OAI/2.0/oai_marc.xsd") do

        xml.tag!("oai_marc:fixfield", record[:identifier], id: "001")
        xml.tag!("oai_marc:varfield", id: "245", i1: "0", i2: "0") do
          xml.tag!("oai_marc:subfield", record[:title], label: "a") if record[:title]
        end
      end
    end
  end
end
