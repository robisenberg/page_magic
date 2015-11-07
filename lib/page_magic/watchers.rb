require 'page_magic/watcher'

module PageMagic
  # module Watchers - contains methods for adding watchers and checking them
  module Watchers
    ELEMENT_MISSING_MSG = 'No element or method with that name defined'

    # @param [Symbol] name - the name of the watcher
    # @return [Boolean] true if a change is detected
    def changed?(name)
      watched_element = watcher(name)
      watched_element.last != watched_element.check(self).last
    end

    # register a new watcher
    # @param [Object] name of the watcher/element
    # @param [Symbol] method - the method on the watched element to check
    # @yieldreturn [Object] the value that should be checked
    # @example
    #  watch(:price, :text)
    # @example
    #  watch(:something) do
    #   # more complicated code to get value
    # end
    def watch(name, method = nil, &block)
      fail ElementMissingException, ELEMENT_MISSING_MSG unless block || respond_to?(name)
      watched_element = block ? Watcher.new(name, &block) : Watcher.new(name, method)
      watchers << watched_element.check(self)
    end

    # @return [Watcher] watcher with the given name
    def watcher(name)
      watchers.find { |watcher| watcher.name == name }
    end

    # @return [Array] registered watchers
    def watchers
      @watchers ||= []
    end
  end
end
