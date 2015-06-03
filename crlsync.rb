#!/usr/bin/ruby

require 'fileutils'
require 'net/http'
require 'net/https'
require 'openssl'
require 'tempfile'
require 'uri'

module MCollective
  module Agent
    class Crlsync < RPC::Agent
      action 'sync' do
        config = puppet_config([:server, :environment, :hostcrl, :user, :group, :hostcert, :hostprivkey, :localcacert])

        master_hostname = config['server']
        environment = config['environment']
        target_crl = request[:crl] || config['hostcrl']
        user = config['user']
        group = config['group']
        cert_file = config['hostcert']
        key_file = config['hostprivkey']
        cacert_file = config['localcacert']

        [cert_file, key_file, cacert_file].each do |f|
          unless File.exist?(f)
            reply[:output] = "#{f} does not exist; aborting."
            return
          end
        end

        cert_data = File.read(cert_file)
        key_data = File.read(key_file)

        ContentURI = URI.parse("https://#{master_hostname}:8140/#{environment}/certificate_revocation_list/ca")

        req = Net::HTTP::Get.new(ContentURI.path)
        https = Net::HTTP.new(ContentURI.host, ContentURI.port)
        https.use_ssl = true
        https.cert = OpenSSL::X509::Certificate.new(cert_data)
        https.key = OpenSSL::PKey::RSA.new(key_data)
        https.verify_mode = OpenSSL::SSL::VERIFY_PEER
        https.ca_file = cacert_file

        begin
          resp = https.start { |cx| cx.request(req) }
        rescue Exception => e
          reply[:output] = "Failed to make request: #{e.message}"
          return
        end

        if resp.code != '200'
          reply[:output] = "Failed to retrieve CRL: #{resp.code}: #{resp.message}"
          return
        end

        # Ensure the retrieved CRL is valid for the CA
        tmpfile = Tempfile.new('crl.pem')
        File.open(tmpfile, File::WRONLY | File::CREAT, 0644) { |f| f.puts resp.body }

        crl = OpenSSL::X509::CRL.new(File.read(tmpfile))
        ca = OpenSSL::X509::Certificate.new(File.read(cacert_file))
        if crl.verify(ca.public_key)
          reply[:output] = crl.last_update
          File.open(target_crl, File::WRONLY | File::CREAT, 0644) { |f| f.puts resp.body }
          FileUtils.chown(user, group, target_crl)
          tmpfile.unlink
        else
          reply[:output] = "Unable to verify CRL with #{cacert_file}"
          tmpfile.unlink
          return
        end
      end

      def puppet_config(keys)
        config_s = %x[puppet config print #{keys.join(' ')}].chop
        Hash[config_s.split(/\n/).map { |str| str.split(' = ') }]
      end
    end
  end
end
