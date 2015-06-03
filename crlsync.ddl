metadata :name        => "PuppetCA CRL sync agent",
         :description => "Retrieve CRL from the designated master",
         :author      => "Jasper Lievisse Adriaanse",
         :license     => "MIT",
         :version     => "1.0",
         :url         => "https://github.com/jasperla/mcollective-crlsync-agent",
         :timeout     => 60

action "sync", :description => "Retrieve the latest CRL" do
  display :always

  input :crl,
        :description => 'Target file to save crl as',
        :prompt      => 'Target file',
        :type        => :string,
        :validation  => '^.+$',
        :optional    => true,
        :default     => '${ssldir}/crl.pem',
        :maxlength   => 256

  output :output,
         :description => 'Last update of CRL',
         :display_as  => 'Last update of CRL'
end
