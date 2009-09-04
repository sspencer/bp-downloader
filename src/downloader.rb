require 'rbconfig'
require 'fileutils'
require 'open-uri'
require 'uri'
include Config

class Downloader
  def initialize(args)
    @tempDir = args["temp_dir"]
    Dir.mkdir(@tempDir)
    if CONFIG['arch'] =~ /mswin/
      @platform = "Windows"
    else
      @platform = "Darwin"
    end

    # keep uri around for relative path resolution
    @uri = URI.parse(args['uri'])
    @scheme = uri.scheme
    @host = uri.host
    @port = uri.port
    
    bp_log("info", "session initialized from #{@scheme}://#{@host}:#{@port}")

    @fileNumber = 0
  end

  def get(bp, args)
    url = args['url']

    # parse url supporting relative urls
    uri = nil
    begin
      uri = URI.parse(url)
      uri = uri.host ? uri : URI.join(@uri.to_s, url)
    rescue Exception
      bp.error("ParamError", "Couldn't parse url argument: #{url}")
      return
    end
    
    if (!uri || uri.scheme != @scheme || uri.host != @host || uri.port != @port)
      bp_log("warn", "download denied, host mismatch " +
             "(#{uri.scheme}://#{uri.host}:#{@port} != #{@scheme}://#{@host}:#{@port})")
      bp.error("SecurityError", "Can only download files from same host.")
      return
    end
    
    perms = @platform == "Windows" ? "wb" : "w"
    path = @tempDir + "/" + "downloaded_" + @fileNumber.to_s
    @fileNumber += 1
    f = File.new(path, perms)

    totalSize = 0
    lastPercent = 0
    interval = 1

    f.write(open(url,
                 :content_length_proc => lambda {|t|
                   if (t && t > 0)
                     totalSize = t
                   end
                 },
                 :progress_proc => lambda {|s|
                   if (totalSize > 0)
                     percent = ((s.to_f / totalSize) * 100).to_i
                     if (percent/interval > lastPercent/interval)
                       lastPercent = percent
                       if args.include? "callback"
                         args["callback"].invoke(percent)
                       end
                     end
                   end
                 }).read)
    f.close()
    
    bp.complete(Pathname.new(path))
  end
end

rubyCoreletDefinition = {
  'class' => "Downloader",
  'name'  => "Downloader",
  'major_version' => 0,
  'minor_version' => 0,
  'micro_version' => 3,
  'documentation' => 
    'Download remote files over HTTP to a temporary location and return file handles to javascript.',

  'functions' =>
  [
    {
      'name' => 'get',
      'documentation' => "Accepts a url, returns a BrowserPlus file handle.",
      'arguments' =>
      [
         {
            'name' => 'url',
            'type' => 'string',
            'required' => true,
            'documentation' => 'the url to the content to download.'
          },
          {
            'name' => 'callback',
            'type' => 'callback',
            'required' => false,
            'documentation' => 'download progress'
          }
      ]
    }
  ] 
}

