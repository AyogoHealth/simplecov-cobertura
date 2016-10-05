require 'rexml/document'
require 'rexml/element'

module SimpleCov
  module Formatter
    class CoberturaFormatter
      VERSION = '1.1.1-dev'

      RESULT_FILE_NAME = 'coverage.xml'
      DTD_URL = 'http://cobertura.sourceforge.net/xml/coverage-04.dtd'

      def format(result)
        xml_doc = result_to_xml result
        result_path = File.join(SimpleCov.coverage_path, RESULT_FILE_NAME)

        formatter = REXML::Formatters::Pretty.new
        formatter.compact = true
        string_io = StringIO.new
        formatter.write(xml_doc, string_io)

        xml_str = string_io.string
        File.write(result_path, xml_str)
        puts "Coverage report generated for #{result.command_name} to #{result_path}"
        xml_str
      end

      private
      def result_to_xml(result)
        doc = REXML::Document.new set_xml_head
        doc.context[:attribute_quote] = :quote
        doc.add_element REXML::Element.new('coverage')
        coverage = doc.root

        set_coverage_attributes(coverage, result)

        coverage.add_element(sources = REXML::Element.new('sources'))
        sources.add_element(source = REXML::Element.new('source'))
        source.text = SimpleCov.root

        coverage.add_element(packages = REXML::Element.new('packages'))

        if result.groups.empty?
          groups = {File.basename(SimpleCov.root) => result.files}
        else
          groups = result.groups
        end

        groups.map do |name, files|
          packages.add_element(package = REXML::Element.new('package'))
          set_package_attributes(package, name, files)

          package.add_element(classes = REXML::Element.new('classes'))

          files.each do |file|
            classes.add_element(class_ = REXML::Element.new('class'))
            set_class_attributes(class_, file)

            class_.add_element(REXML::Element.new('methods'))
            class_.add_element(lines = REXML::Element.new('lines'))

            file.lines.each do |file_line|
              if file_line.covered? || file_line.missed?
                lines.add_element(line = REXML::Element.new('line'))
                set_line_attributes(line, file_line)
              end
            end
          end
        end

        doc
      end

      def set_coverage_attributes(coverage, result)
        coverage.attributes['line-rate'] = (result.covered_percent/100).round(2).to_s
        coverage.attributes['branch-rate'] = '0'
        coverage.attributes['lines-covered'] = result.covered_lines.to_s
        coverage.attributes['lines-valid'] = (result.covered_lines + result.missed_lines).to_s
        coverage.attributes['branches-covered'] = '0'
        coverage.attributes['branches-valid'] = '0'
        coverage.attributes['branch-rate'] = '0'
        coverage.attributes['complexity'] = '0'
        coverage.attributes['version'] = '0'
        coverage.attributes['timestamp'] = Time.now.to_i.to_s
      end

      def set_package_attributes(package, name, result)
        package.attributes['name'] = name
        package.attributes['line-rate'] = (result.covered_percent/100).round(2).to_s
        package.attributes['branch-rate'] = '0'
        package.attributes['complexity'] = '0'
      end

      def set_class_attributes(class_, file)
        filename = file.filename
        path = filename[SimpleCov.root.length+1..-1]
        class_.attributes['name'] = File.basename(filename, '.*')
        class_.attributes['filename'] = path
        class_.attributes['line-rate'] = (file.covered_percent/100).round(2).to_s
        class_.attributes['branch-rate'] = '0'
        class_.attributes['complexity'] = '0'
      end

      def set_line_attributes(line, file_line)
        line.attributes['number'] = file_line.line_number.to_s
        line.attributes['branch'] = 'false'
        line.attributes['hits'] = file_line.coverage.to_s
      end

      def set_xml_head(lines=[])
        lines << "<?xml version=\"1.0\"?>"
        lines << "<!DOCTYPE coverage SYSTEM \"#{DTD_URL}\">"
        lines << "<!-- Generated by simplecov-cobertura version #{VERSION} (https://github.com/dashingrocket/simplecov-cobertura) -->"
        lines.join("\n")
      end
    end
  end
end
