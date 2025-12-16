require 'rails_helper'

#to run
#bundle exec rspec spec/controllers/oai_controller_list_sets_spec.rb
RSpec.describe OaiController, type: :controller do
  describe "GET #index with verb=ListSets" do
    let(:response_xml) { Nokogiri::XML(response.body) }

    context "successful request" do
      before do
        get :index, params: { verb: "ListSets" }
      end

      it "returns http success" do
        expect(response).to have_http_status(:success)
      end

      it "returns XML content type" do
        expect(response.content_type).to include("xml")
      end

      it "includes OAI-PMH root element with correct namespaces" do
        expect(response_xml.root.name).to eq("OAI-PMH")
        expect(response_xml.root.namespace.href).to eq("http://www.openarchives.org/OAI/2.0/")
      end

      it "includes responseDate element" do
        response_date = response_xml.xpath("//xmlns:responseDate",
          'xmlns' => 'http://www.openarchives.org/OAI/2.0/').first
        expect(response_date).to be_present
        expect(response_date.text).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      end

      it "includes request element with verb attribute" do
        request_element = response_xml.xpath("//xmlns:request",
          'xmlns' => 'http://www.openarchives.org/OAI/2.0/').first
        expect(request_element).to be_present
        expect(request_element['verb']).to eq("ListSets")
      end

      it "includes ListSets element" do
        list_sets = response_xml.xpath("//xmlns:ListSets",
          'xmlns' => 'http://www.openarchives.org/OAI/2.0/').first
        expect(list_sets).to be_present
      end

      it "returns two sample sets" do
        sets = response_xml.xpath("//xmlns:set",
          'xmlns' => 'http://www.openarchives.org/OAI/2.0/')
        expect(sets.count).to eq(3)
      end

      it "includes setSpec elements for each set" do
        set_specs = response_xml.xpath("//xmlns:setSpec",
          'xmlns' => 'http://www.openarchives.org/OAI/2.0/')
        expect(set_specs.map(&:text)).to contain_exactly("ycba%3Aframes", "ycba%3Apd","ycba%3Aps")
      end

      it "includes setName elements for each set" do
        set_names = response_xml.xpath("//xmlns:setName",
          'xmlns' => 'http://www.openarchives.org/OAI/2.0/')
        expect(set_names.map(&:text)).to contain_exactly("YCBA frame collection", "Prints and Drawings","Paintings and Sculpture")
      end

      it "includes setDescription elements with proper namespace" do
        set_descriptions = response_xml.xpath("//xmlns:setDescription",
          'xmlns' => 'http://www.openarchives.org/OAI/2.0/')
        expect(set_descriptions.count).to eq(3)

        # Check Dublin Core namespace is present in setDescription
        set_descriptions.each do |desc|
          dc_namespace = desc.namespaces.values.include?("http://purl.org/dc/elements/1.1/")
          expect(dc_namespace).to be true
        end
      end

      it "includes description text within Dublin Core namespace" do
        descriptions = response_xml.xpath("//xmlns:setDescription/dc:description",
          'xmlns' => 'http://www.openarchives.org/OAI/2.0/',
          'dc' => 'http://purl.org/dc/elements/1.1/')
        expect(descriptions.map(&:text)).to contain_exactly(
          "YCBA frame collection",
          "Prints and Drawings",
          "Paintings and Sculpture"
        )
      end

      describe "first set structure" do
        let(:first_set) do
          response_xml.xpath("//xmlns:set",
            'xmlns' => 'http://www.openarchives.org/OAI/2.0/').first
        end

        it "has correct setSpec" do
          spec = first_set.xpath("xmlns:setSpec",
            'xmlns' => 'http://www.openarchives.org/OAI/2.0/').first
          expect(spec.text).to eq("ycba%3Aframes")
        end

        it "has correct setName" do
          name = first_set.xpath("xmlns:setName",
            'xmlns' => 'http://www.openarchives.org/OAI/2.0/').first
          expect(name.text).to eq("YCBA frame collection")
        end

        it "has correct setDescription" do
          desc = first_set.xpath("xmlns:setDescription/dc:description",
            'xmlns' => 'http://www.openarchives.org/OAI/2.0/',
            'dc' => 'http://purl.org/dc/elements/1.1/').first
          expect(desc.text).to eq("YCBA frame collection")
        end
      end
    end

    context "error handling" do
      context "when illegal arguments are provided" do
        before do
          get :index, params: { verb: "ListSets", metadataPrefix: "oai_dc" }
        end

        it "returns http success with error" do
          expect(response).to have_http_status(:success)
        end

        it "returns error element" do
          error_element = response_xml.xpath("//xmlns:error",
            'xmlns' => 'http://www.openarchives.org/OAI/2.0/').first
          expect(error_element).to be_present
        end

        it "returns badArgument error code" do
          error_element = response_xml.xpath("//xmlns:error",
            'xmlns' => 'http://www.openarchives.org/OAI/2.0/').first
          expect(error_element['code']).to eq("badArgument")
        end

        it "returns appropriate error message" do
          error_element = response_xml.xpath("//xmlns:error",
            'xmlns' => 'http://www.openarchives.org/OAI/2.0/').first
          expect(error_element.text).to eq("The request includes illegal arguments")
        end

        it "does not include ListSets element" do
          list_sets = response_xml.xpath("//xmlns:ListSets",
            'xmlns' => 'http://www.openarchives.org/OAI/2.0/')
          expect(list_sets).to be_empty
        end
      end

      context "when multiple illegal arguments are provided" do
        before do
          get :index, params: {
            verb: "ListSets",
            metadataPrefix: "oai_dc",
            from: "2024-01-01",
            identifier: "test:123"
          }
        end

        it "returns badArgument error" do
          error_element = response_xml.xpath("//xmlns:error",
            'xmlns' => 'http://www.openarchives.org/OAI/2.0/').first
          expect(error_element['code']).to eq("badArgument")
          expect(error_element.text).to eq("The request includes illegal arguments")
        end
      end
    end

    context "XML structure validation" do
      before do
        get :index, params: { verb: "ListSets" }
      end

      it "returns well-formed XML" do
        expect { Nokogiri::XML(response.body) { |config| config.strict } }.not_to raise_error
      end

      it "has correct XML encoding declaration" do
        expect(response.body).to match(/\<\?xml version/)
        expect(response.body).to match(/encoding="UTF-8"/)
      end

      it "includes proper schema location" do
        expect(response_xml.root['xsi:schemaLocation']).to eq(
          "http://www.openarchives.org/OAI/2.0/ http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd"
        )
      end
    end
  end
end
