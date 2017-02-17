# rubocop:disable Metrics/ModuleLength
module PageMagic
  describe Elements do
    include_context :nested_elements_html

    let(:page) { double(init: nested_elements_node) }

    subject do
      Class.new do
        extend Elements
        include Element::Locators
      end
    end
    let(:instance) do
      subject.new
    end

    let(:child_selector) { { id: 'child' } }

    describe '#element' do
      it 'sets the selector and type' do
        expected_definition = ElementDefinitionBuilder.new(definition_class: Element,
                                                           type: :text_field,
                                                           selector: child_selector,
                                                           options: { multiple_results: false })
        subject.text_field :alias, child_selector
        expect(instance.element_by_name(:alias)).to eq(expected_definition)
      end

      context 'options' do
        it 'puts them on the builder' do
          options = { my: :options }
          subject.text_field :alias, child_selector, options
          expect(instance.element_by_name(:alias).options).to eq(options)
        end
      end

      context 'complex elements' do
        let!(:section_class) do
          Class.new(Element) do
            def self.name
              'PageSection'
            end
          end
        end

        context 'using a predefined class' do
          it 'should add an element using that class section' do
            subject.element section_class, :page_section, child_selector
            element_definition_builder = instance.element_by_name(:page_section)
            expect(element_definition_builder.definition_class).to be < section_class
          end

          context 'with no selector supplied' do
            it 'defaults the selector to the one on the class' do
              section_class.selector child_selector
              subject.element section_class, :alias
              element_definition_builder = instance.element_by_name(:alias)
              expect(element_definition_builder.selector).to eq(child_selector)
            end
          end

          context 'with no name supplied' do
            it 'should default to the name of the class if one is not supplied' do
              subject.element section_class, child_selector
              element_definition_builder = instance.element_by_name(:page_section)
              expect(element_definition_builder.definition_class).to be < section_class
            end
          end
        end
      end

      context 'using a block' do
        it 'passes the parent element in as the last argument' do
          expected_element = instance
          subject.element :page_section, child_selector do |_arg1|
            extend RSpec::Matchers
            expect(parent_element).to eq(expected_element)
          end
          instance.element_by_name(:page_section, :arg1)
        end

        it 'should pass args through to the block' do
          subject.element :page_section, child_selector do |arg|
            extend RSpec::Matchers
            expect(arg).to eq(:arg1)
          end

          instance.element_by_name(:page_section, :arg1)
        end
      end

      describe 'location' do
        context 'a prefetched object' do
          it 'should add a section' do
            subject.element :page_section, :object

            element_defintion_builder = instance.element_by_name(:page_section)
            expect(element_defintion_builder.element).to eq(:object)
          end
        end
      end

      describe 'restrictions' do
        subject do
          Class.new.tap do |clazz|
            clazz.extend(described_class)
          end
        end

        it 'should not allow method names that match element names' do
          expect do
            subject.class_eval do
              link(:hello, text: 'world')

              def hello; end
            end
          end.to raise_error(InvalidMethodNameException)
        end

        it 'should not allow element names that match method names' do
          expect do
            subject.class_eval do
              def hello; end

              link(:hello, text: 'world')
            end
          end.to raise_error(InvalidElementNameException)
        end

        it 'should not allow duplicate element names' do
          expect do
            subject.class_eval do
              link(:hello, text: 'world')
              link(:hello, text: 'world')
            end
          end.to raise_error(InvalidElementNameException)
        end

        it 'should not evaluate the elements when applying naming checks' do
          subject.class_eval do
            link(:link1, :selector) do
              raise('should not have been evaluated')
            end
            link(:link2, :selector)
          end
        end
      end
    end

    describe '#element_definitions' do
      it 'should return your a copy of the core definition' do
        subject.text_field :alias, child_selector
        first = instance.element_by_name(:alias)
        second = instance.element_by_name(:alias)
        expect(first).to_not equal(second)
      end
    end
  end
end
