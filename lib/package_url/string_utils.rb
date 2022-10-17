# frozen_string_literal: true

class PackageURL
  module StringUtils
    private

    def strip(string, char)
      string.delete_prefix(char).delete_suffix(char)
    end

    def parse_segments(string)
      strip(string, '/').split('/')
    end

    def segment_present?(segment)
      !segment.empty? && segment != '.' && segment != '..'
    end

    # Partition the given string on the separator.
    # The side being partitioned from is returned as the value,
    # with the opposing side being returned as the remainder.
    #
    # If a block is given, then the (value, remainder) are given
    # to the block, and the return value of the block is used as the value.
    #
    # If `require_separator` is true, then a nil value will be returned
    # if the separator is not present.
    def partition(string, sep, from: :left, require_separator: true)
      value, separator, remainder = if from == :left
                                      left, separator, right = string.partition(sep)
                                      [left, separator, right]
                                    else
                                      left, separator, right = string.rpartition(sep)
                                      [right, separator, left]
                                    end

      return [nil, value] if separator.empty? && require_separator

      value = yield(value, remainder) if block_given?

      [value, remainder]
    end
  end
end
