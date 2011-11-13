require 'test/unit'
require 'autotm'

include Autotm

def get_conf
  {"servers"=>[
    {"username"=>"jdoe", "hostname"=>"localhost", "password"=>"s3cr3t"},
    {"username"=>"jdoe", "hostname"=>"www.google.com", "password"=>"s3cr3t"}
    ]
  }
end

class TestAutotm < Test::Unit::TestCase

  def test_01_ping
    res = ping('localhost')
    assert(res > 0)
  end


  def test_02_available_servers
    servers = get_available_servers()
    assert_equal(2, servers.count)
    # localhost should always be quicker than google.com
    assert_equal('localhost', servers[0]['hostname'])
    assert_equal('www.google.com', servers[1]['hostname'])
  end

end
