module Rusby
  module Core
    MIN_BOOST_PERCENT = -50 # heh, have to change the sign

    # next method should be added to the rusby table
    def rusby!
      @rusby_awaits_method = true
    end

    def rusby_replace_method(method_name, method_reference)
      @rusby_skips_method = true
      define_method(method_name, method_reference)
    end

    def rusby_type(object)
      object.class == Array ? "Array[#{object[0].class}]" : object.class.to_s
    end

    # proxy method that records arg and result types
    def rusby_method_proxy(object, method_name, method_reference, args)
      bound_method = method_reference.bind(object)
      result = bound_method.call(*args)

      @rusby_method_table[method_name][:args] = args.map { |arg| rusby_type(arg) }
      @rusby_method_table[method_name][:arg_slugs] = args.map { |arg| rusby_type(arg).gsub(/\W/, '_').downcase }
      @rusby_method_table[method_name][:result] = rusby_type(result)
      @rusby_method_table[method_name][:result_slug] = rusby_type(result).gsub(/\W/, '_').downcase

      if @rusby_method_table[method_name][:exposed]
        # try to convert to rust or return back the original method
        rusby_convert_or_bust(method_name, method_reference, object, args)
      else
        # if we don't need to convert method to rust return back the original method
        rusby_replace_method(method_name, method_reference)
      end

      result
    end

    def rusby_ffi_wrapper(method_name, method_reference, args)
      tm = TypeMapper.new
      arg_types = @rusby_method_table[method_name][:arg_slugs]
      ffi_args = arg_types.each_with_index.map do |arg_type, i|
        tm.send("#{arg_type}_to_ffi", args[i])
      end.flatten
      ffi_result = method_reference.call(*ffi_args)
      result_type = @rusby_method_table[method_name][:result_slug]
      tm.send("#{result_type}_from_ffi", ffi_result)
    end

    def rusby_convert_or_bust(method_name, method_reference, object, args)
      # if we are converting recursive function
      # we need to wait for it to exit all recursive calls
      return if caller.any? { |entry| entry.include?("`#{method_name}'") }

      rust_method = Builder.convert_to_rust(
        @rusby_method_table,
        method_name,
        method_reference,
        object
      )

      wrapped_rust_method = lambda do |*args|
        object.class.rusby_ffi_wrapper(method_name, rust_method, args)
      end

      # check if rust method is running faster than the original one
      boost = Profiler.benchit(object, method_reference, wrapped_rust_method, args)

      # coose between rust and ruby methods
      resulting_method = method_reference
      if true # boost > MIN_BOOST_PERCENT
        puts "\u2605\u2605\u2605  Running Rust! Yeeeah Baby! \u2605\u2605\u2605"
        resulting_method = wrapped_rust_method
      end

      # set chosen method permanently
      rusby_replace_method(method_name, resulting_method)
    end

    # module callbacks
    def method_added(method_name)
      super

      if @rusby_skips_method
        @rusby_skips_method = false
        return
      end

      @rusby_method_table ||= {}
      @rusby_method_table[method_name] = {}

      if @rusby_awaits_method
        @rusby_awaits_method = false
        @rusby_method_table[method_name][:exposed] = true
      end

      original_method = instance_method(method_name)
      new_method = lambda do |*args|
        self.class.rusby_method_proxy(
          self,
          method_name,
          original_method,
          args
        )
      end
      rusby_replace_method(method_name, new_method)
    end

    def singleton_method_added(method_name)
      # TODO
    end
  end
end
