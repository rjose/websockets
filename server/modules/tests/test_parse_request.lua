RequestParser = require('request_parser')
require('string_utils')

TestParseRequest = {}

-- SETUP ----------------------------------------------------------------------
--
function TestParseRequest:setUp()
        local tmp = {}
        tmp[#tmp+1] = "GET / HTTP/1.1"
        tmp[#tmp+1] = "Host: localhost:8888"
        tmp[#tmp+1] = "Connection: keep-alive"
        tmp[#tmp+1] = "Cache-Control: max-age=0"
        tmp[#tmp+1] = "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" 
        tmp[#tmp+1] = "User-Agent: Mozilla/5.0 (X11; FreeBSD i386; rv:20.0) Gecko/20100101 Firefox/20.0"
        tmp[#tmp+1] = "Accept-Encoding: gzip,deflate,sdch"
        tmp[#tmp+1] = "Accept-Language: en-US,en;q=0.8"
        tmp[#tmp+1] = 'Cookie: visit="v=1&G"'
        tmp[#tmp+1] = ''

        -- Set up valid request
        self.request_string = table.concat(tmp, "\r\n")

        -- Set up request with a route
        tmp = {}
        tmp[#tmp+1] = "GET /app/web/rrt HTTP/1.1"
        tmp[#tmp+1] = "Host: localhost:8888"
        tmp[#tmp+1] = "Accept: text/json"
        self.request_string_w_route = table.concat(tmp, "\r\n")

        -- Set up request with a query string
        tmp = {}
        tmp[#tmp+1] = "GET /app/web/rbt?triage=1&track=sop HTTP/1.1"
        tmp[#tmp+1] = "Host: localhost:8888"
        tmp[#tmp+1] = "Accept: text/json"
        self.request_string_w_query = table.concat(tmp, "\r\n")

        -- Set up request with multiple cookies
        tmp = {}
        tmp[#tmp+1] = "GET / HTTP/1.1"
        tmp[#tmp+1] = "Host: localhost:8888"
        tmp[#tmp+1] = 'Cookie: name="Borvo"; auth="123"'
        self.request_string_w_cookies = table.concat(tmp, "\r\n")
end


function TestParseRequest:test_parse_simple_request()
        local req = RequestParser.parse_request(self.request_string)
        assertEquals(req.method, "GET")
        assertEquals(req.request_target, "/")
        assertEquals(req.headers['host'], "localhost:8888")
        assertEquals(req.headers['user-agent'], "Mozilla/5.0 (X11; FreeBSD i386; rv:20.0) Gecko/20100101 Firefox/20.0")
end


function TestParseRequest:test_request_with_route()
        local req = RequestParser.parse_request(self.request_string_w_route)
        assertEquals(req.method, "GET")
        assertEquals(req.request_target, "/app/web/rrt")
end


function TestParseRequest:test_request_with_query()
        local req = RequestParser.parse_request(self.request_string_w_query)
        assertEquals(req.method, "GET")
        assertEquals(req.request_target, "/app/web/rbt?triage=1&track=sop")
        assertEquals(req.qparams.triage, {"1"})
        assertEquals(req.qparams.track, {"sop"})
end


function TestParseRequest:test_request_with_cookies()
        local req = RequestParser.parse_request(self.request_string_w_cookies)
        assertEquals(req.method, "GET")
        assertEquals(req.request_target, "/")
        assertEquals(req.headers.cookie, 'name="Borvo"; auth="123"')
        assertEquals(req.cookies['name'], "Borvo")
        assertEquals(req.cookies['auth'], "123")
end
