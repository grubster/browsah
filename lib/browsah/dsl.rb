# encoding: UTF-8

require 'em-synchrony/em-http'

class Browsah
  module Dsl
    def initialize(uri = '')
      @base_uri = uri.kind_of?(String) ? Addressable::URI.parse(uri) : uri
      @pull = []
    end
    
    def get(urls, *args, &block)
      urls  = urls.kind_of?(Array) ? urls : [urls]
      urls += args
      
      @pull << urls.map { |url|
        request = Request.new(@base_uri, url)
      }
      on_done(&block) if block_given?
    end
    
    def rule
    end
    
    def on_done(&block)
      result = nil
      EM.synchrony do
        multi     = EM::Synchrony::Multi.new
        responses = []
        
        @pull.each do |requests|
          if (is_multi = requests.size > 1)
            responses << []
            index = responses.size - 1
          end
          
          requests.each do |request|
            http = EM::HttpRequest.new(request.uri.to_s).aget
            http.callback {
              response = Response.new(self, http.response_header.status, {}, http.response)
              (is_multi ? responses[index] : responses) << response
            }
            multi.add request.uri.to_s.to_sym, http
          end
          
        end
        
        # Clean pull of request
        @pull = []
        
        multi.perform
        result = (block.call(*responses)) if block_given?
        EM.stop
      end
      result
    end
  end
end