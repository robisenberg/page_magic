# rubocop:disable Metrics/ModuleLength
module PageMagic
  describe Session do
    let(:page) do
      Class.new do
        include PageMagic
        url 'http://url.com'
      end
    end

    subject { described_class.new(browser) }

    let(:url) { page.url }
    let(:browser) { double('browser', current_url: "#{url}/somepath", visit: nil, current_path: :current_path) }

    describe '#current_page' do
      let(:another_page_class) do
        Class.new do
          include PageMagic
          url 'http://www.example.com/another_page1'
        end
      end

      before do
        subject.define_page_mappings '/another_page1' => another_page_class
        subject.visit(page, url: url)
      end

      context 'page url has not changed' do
        it 'returns the original page' do
          allow(browser).to receive(:current_url).and_return(page.url)
          expect(subject.current_page).to be_an_instance_of(page)
        end
      end

      context 'page url has changed' do
        it 'returns the mapped page object' do
          allow(browser).to receive(:current_url).and_return(another_page_class.url)
          expect(subject.current_page).to be_an_instance_of(another_page_class)
        end
      end
    end

    describe '#current_path' do
      it "returns the browser's current path" do
        expect(subject.current_path).to eq(browser.current_path)
      end
    end

    describe '#current_url' do
      it "returns the browser's current url" do
        expect(subject.current_url).to eq(browser.current_url)
      end
    end

    describe '#define_page_mappings' do
      context 'mapping includes a literal' do
        it 'creates a matcher to contain the specification' do
          subject.define_page_mappings path: :page
          expect(subject.transitions).to eq(Matcher.new(:path) => :page)
        end
      end

      context 'mapping is a matcher' do
        it 'leaves it intact' do
          expected_matcher = Matcher.new(:page)
          subject.define_page_mappings expected_matcher => :page
          expect(subject.transitions.key(:page)).to be(expected_matcher)
        end
      end
    end

    describe '#execute_script' do
      it 'calls the execute script method on the capybara session' do
        expect(browser).to receive(:execute_script).with(:script).and_return(:result)
        expect(subject.execute_script(:script)).to be(:result)
      end

      context 'Capybara session does not support #execute_script' do
        let(:browser) { Capybara::Driver::Base.new }
        it 'raises an error' do
          expected_message = described_class::UNSUPPORTED_OPERATION_MSG
          expect { subject.execute_script(:script) }.to raise_error(NotSupportedException, expected_message)
        end
      end
    end

    describe '#find_mapped_page' do
      subject do
        described_class.new(nil)
      end

      context 'match found' do
        it 'returns the page class' do
          subject.define_page_mappings '/page' => :mapped_page_using_string
          expect(subject.instance_eval { find_mapped_page('/page') }).to be(:mapped_page_using_string)
        end

        context 'more than one match is found' do
          it 'returns the most specific match' do
            subject.define_page_mappings %r{/page} => :mapped_page_using_regex, '/page' => :mapped_page_using_string
            expect(subject.instance_eval { find_mapped_page('/page') }).to eq(:mapped_page_using_string)
          end
        end
      end

      context 'mapping is not found' do
        it 'returns nil' do
          expect(subject.instance_eval { find_mapped_page('/fake_page') }).to be(nil)
        end
      end
    end

    describe '#matches' do
      subject do
        described_class.new(nil)
      end

      it 'returns matching page mappings' do
        subject.define_page_mappings '/page' => :mapped_page_using_string
        expect(subject.instance_eval { matches('/page') }).to eq([:mapped_page_using_string])
      end

      context 'more than one match on path' do
        it 'orders the results by specificity ' do
          subject.define_page_mappings %r{/page} => :mapped_page_using_regex, '/page' => :mapped_page_using_string
          expected_result = [:mapped_page_using_string, :mapped_page_using_regex]
          expect(subject.instance_eval { matches('/page') }).to eq(expected_result)
        end
      end
    end

    describe '#method_missing' do
      it 'should delegate to current page' do
        page.class_eval do
          def my_method
            :called
          end
        end

        session = PageMagic::Session.new(browser).visit(page, url: url)
        expect(session.my_method).to be(:called)
      end
    end

    context '#respond_to?' do
      subject do
        PageMagic::Session.new(browser).tap do |s|
          allow(s).to receive(:current_page).and_return(page.new)
        end
      end
      it 'checks self' do
        expect(subject.respond_to?(:current_url)).to eq(true)
      end

      it 'checks the current page' do
        page.class_eval do
          def my_method; end
        end
        expect(subject.respond_to?(:my_method)).to eq(true)
      end
    end

    describe '#url' do
      let!(:base_url) { 'http://example.com' }
      let!(:path) { 'home' }
      let!(:expected_url) { "#{base_url}/#{path}" }

      context 'base_url has a / on the end' do
        before do
          base_url << '/'
        end

        context 'path has / at the beginning' do
          it 'produces compound url' do
            expect(subject.send(:url, base_url, path)).to eq(expected_url)
          end
        end

        context 'path does not have / at the beginning' do
          it 'produces compound url' do
            expect(subject.send(:url, base_url, "/#{path}")).to eq(expected_url)
          end
        end
      end

      context 'current_url does not have a / on the end' do
        context 'path has / at the beginning' do
          it 'produces compound url' do
            expect(subject.send(:url, base_url, "/#{path}")).to eq(expected_url)
          end
        end

        context 'path does not have / at the beginning' do
          it 'produces compound url' do
            expect(subject.send(:url, base_url, path)).to eq(expected_url)
          end
        end
      end
    end

    describe '#visit' do
      let(:session) do
        allow(browser).to receive(:visit)
        PageMagic::Session.new(browser, url)
      end

      context 'page supplied' do
        it 'sets the current page' do
          session.define_page_mappings '/page' => page
          session.visit(page)
          expect(session.current_page).to be_a(page)
        end

        it 'uses the base url and the path in the page mappings' do
          session.define_page_mappings '/page' => page
          expect(browser).to receive(:visit).with("#{url}/page")
          session.visit(page)
        end

        context 'no mappings found' do
          it 'raises an error' do
            expect { session.visit(page) }.to raise_exception InvalidURLException, described_class::URL_MISSING_MSG
          end
        end

        context 'mapping is a regular expression' do
          it 'raises an error' do
            session.define_page_mappings(/mapping/ => page)
            expect { session.visit(page) }.to raise_exception InvalidURLException, described_class::REGEXP_MAPPING_MSG
          end
        end

        it 'calls the onload hook' do
          on_load_hook_called = false
          page.on_load do
            on_load_hook_called = true
          end
          session.define_page_mappings('/page' => page)
          session.visit(page)
          expect(on_load_hook_called).to eq(true)
        end
      end

      context 'url supplied' do
        it 'visits that url' do
          expected_url = 'http://url.com/page'
          expect(browser).to receive(:visit).with(expected_url)
          session.visit(url: expected_url)
        end
      end
    end
  end
end
