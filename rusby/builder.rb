require 'parser/ruby22'
require 'yaml'

module Rusby
  module Builder
    extend self

    def root_path
      @root ||= File.expand_path('../..', __FILE__)
    end

    def rust
      @rust ||= Hashie::Mash.new YAML.load_file("#{root_path}/rust.yaml")
    end

    def convert_to_rust(name, orig_method, _owner, result, *args)
      ast = Parser::Ruby22.parse(orig_method.source)
      p ast
      signature, code = Builder.method_to_rust(ast, args.map(&:class), result.class)
      puts code
      # Builder.inline_methods(code, owner)
      return

      File.open("#{root_path}/lib/#{name}.rs", 'w') { |file| file.write(code) }
      puts "Compiling #{signature.last} #{name}(#{signature.first.join(', ')})..."
      puts `rustc --crate-type=dylib -O -o #{root_path}/lib/#{name}.dylib #{root_path}/lib/#{name}.rs`

      # Proxy.rusby_load "#{root_path}/lib/#{name}"
      # Proxy.attach_function name, *signature
      #
      # Proxy.method(name)
    end

    def inline_methods(code, owner)
      code.gsub(%r{/\*inline\((.+?)\)\*/}) do
        inline_method_to_rust(owner.method(Regexp.last_match(1)).source)
      end
    end

    def inline_method_to_rust(source)
      ast = Parser::Ruby22.parse(source)
      puts ast_to_rust(ast.children[2])
    end

    def method_to_rust(ast, arg_types, return_type)
      result = rust.method_declaration_prefix

      name = ast.children.first
      @method_name = name
      args = ast.children[1].children.each_with_index.map do |child, i|
        "#{child.children[0]}: #{rust.types[arg_types[i]]}"
      end

      result << "#{rust.method_prefix} #{name}(#{args.join(', ')}) -> #{rust.types[return_type]} {"

      ast.children[2..-1].each do |node|
        result << Rust.generate(node)
      end

      result << '}'

      signature = [arg_types.map { |arg| rust.c_types[arg] }, rust.c_types[return_type]]
      [signature, result.join("\n")]
    end
  end
end
