module Rusby
  module Generators
    module Base
      def generate(ast)
        unless ast.respond_to?(:type)
          # ok, it's not ast node, but it could be a method
          # redefine internal ruby methods as needed
          return case ast
                 when :<< || :>>
                   ast
                 when :length
                   '.len()'
                 when :min
                   '.iter().min()'
                 else
                   ast.to_s
                end
        end
        send("generate_#{ast.type.to_s.tr('-', '_')}", ast)
      end

      def generate_send(ast)
        if ast.children[0]
          fold_arrays(ast.children).join
        else
          verb = ast.children[1]
          case verb
          when :puts
            "\nprintln!(\"{}\", #{generate(ast.children[2])});io::stdout().flush().unwrap();\n"
          # argument of this ruby method is rust code "as is"
          when :rust
            ast.children[2].children[0] + ' // generated by Rusby::Preprocessor'
          # mark variabale as already defined
          when :rust_variable
            remember_variable(ast.children[2].children[0])
            nil
          else
            return verb if known_variable?(verb)

            arguments = fold_arrays(ast.children[2..-1])
            result = "#{verb}(#{arguments.join(', ')});"
            result = 'internal_method_' + result unless known_method?(ast.children[1])
            result
          end
        end
      end

      def generate_block(ast)
        block_operator = ast.children[0].children[1]
        case block_operator
        when :loop
          generate_loop(ast)
        when :each
          generate_each_loop(ast)
        when :each_with_index
          generate_each_with_index_loop(ast)
        when :rust
          ast.children[1..-1].to_s
        else
          statements = ast.children[1..-1].map { |node| generate(node) }.compact
          "#{ast.children[0].children[1]} {\n#{statements.join("\n")}\n}"
        end
      end
    end
  end
end