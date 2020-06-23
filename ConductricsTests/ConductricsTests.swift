//
//  ConductricsTests.swift
//  ConductricsTests
//
//  Created by Jesse Granger on 6/22/20.
//  Copyright © 2020 Conductrics. All rights reserved.
//

import XCTest
import Conductrics

class ConductricsTests: XCTestCase {
    private var api : Conductrics = Conductrics(
        apiUrl:"https://api-staging-2020.conductrics.com/owner_jesse/v3/agent-api",
        apiKey:"api-JQXuiRRrCRkKPXPhChMC")
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func debugJSON(_ json : [String:Any]?) -> String {
        if let json = json {
            do {
                let data : Data = try JSONSerialization.data(withJSONObject:json, options:[] )
                return String(data:data, encoding: .utf8) ?? "{}"
            } catch {
                return error.localizedDescription;
            }
        } else {
            return "nil";
        }
    }
    func Lock() -> DispatchSemaphore {
        return DispatchSemaphore(value: 0)
    }
    
    func assertListContains( value: String, list:[String]) {
        var match = false;
        for line in list {
            if line == value {
                match = true;
                break;
            }
        }
        XCTAssertEqual(match, true);
    }
    
    func testBasicSession() throws {
        let opts = Conductrics.RequestOptions(nil)
        let lock = Lock()
        api.select(opts, "a-example", { response in
            let optionCode = response.getCode()
            XCTAssert( optionCode == "A" || optionCode == "B", "must chose variant A or B, not " + optionCode);
            XCTAssert( response.getError() == nil, "error should be nil, got: " + String(describing: response.getError()))
            lock.signal()
        })
        lock.wait()
    }

    func testSessionIsSticky() throws {
        let opts = Conductrics.RequestOptions(nil)
        let lock = Lock()
        api.select(opts, "a-example", { response in
            let optionCode = response.getCode()
            XCTAssert( optionCode == "A" || optionCode == "B", "must chose variant A or B, not " + optionCode);
            XCTAssert( response.getError() == nil, "error should be nil, got: " + String(describing: response.getError()))
            XCTAssert( response.getPolicy() == Conductrics.Policy.Random, "policy should be random, got: " + String( describing: response.getPolicy()));
            self.api.select(opts, "a-example", { response in
                XCTAssert( response.getCode() == optionCode, "expected: "+optionCode+" got: "+response.getCode());
                XCTAssert( response.getPolicy() == Conductrics.Policy.Sticky, "expected sticky policy, got: " + String( describing: response.getPolicy()) )
                lock.signal()
            })
        })
        lock.wait()
    }
    
    func testTraits() throws {
        let opts = Conductrics.RequestOptions(nil)
            .setTrait("F","1")
            .setTrait("F","2")
        let lock = Lock()
        api.select(opts, "a-example", { response in
            XCTAssertEqual(response.getAgent(), "a-example")
            XCTAssertEqual(response.getPolicy(), Conductrics.Policy.Random)
            XCTAssertEqual(
                response.getExecResponse()?.getTraits().joined(separator: ","),
                "cust/F:1,cust/F:2"
            )
            lock.signal()
        })
        lock.wait()
    }
    
    func testParams() throws {
        let opts = Conductrics.RequestOptions(nil)
            .setParam("debug", "true")
        let lock = Lock()
        api.select(opts, "a-example", { response in
            XCTAssertEqual(response.getAgent(), "a-example")
            XCTAssertEqual(response.getPolicy(), Conductrics.Policy.Random)
            XCTAssertGreaterThan(response.getExecResponse()?.getLog()?.count ?? 0, 0)
            lock.signal()
        })
        lock.wait()
    }

    func testSetDefault() throws {
        let opts = Conductrics.RequestOptions(nil)
            .setDefault("a-invalid", "Z");
        let lock = Lock()
        api.select(opts, "a-invalid", { response in
            XCTAssertEqual(response.getAgent(), "a-invalid")
            XCTAssertEqual(response.getCode(), "Z")
            XCTAssertEqual(response.getPolicy(), Conductrics.Policy.None)
            lock.signal()
        })
        lock.wait()
    }
    
    func testForceOutcome() throws {
        let opts = Conductrics.RequestOptions(nil)
            .forceOutcome("a-example", "Z");
        let lock = Lock()
        api.select(opts, "a-example", { response in
            XCTAssertEqual(response.getAgent(), "a-example")
            XCTAssertEqual(response.getCode(), "Z")
            XCTAssertEqual(response.getPolicy(), Conductrics.Policy.None)
            lock.signal()
        })
        lock.wait()
    }
    
    func testUserAgent() throws {
        let opts = Conductrics.RequestOptions(nil)
            .setUserAgent(ua: "MAGIC STRING")
            .setParam("debug", "true");
        let lock = Lock()
        api.select(opts, "a-example", { response in
            XCTAssertEqual(response.getAgent(), "a-example")
            XCTAssertEqual(response.getPolicy(), Conductrics.Policy.Random)
            self.assertListContains( value: "Added trait 'ua/mo:n' (apply)",
                                     list: response.getExecResponse()?.getLog() ?? [String]())
            lock.signal()
        })
        lock.wait()
    }
    
    func testSetInput() throws {
        let opts = Conductrics.RequestOptions(nil)
            .setInput("foo", "bar");
        let lock = Lock()
        api.select(opts, "a-example", { response in
            XCTAssertEqual(response.getAgent(), "a-example")
            XCTAssertEqual(response.getPolicy(), Conductrics.Policy.Fixed)
            XCTAssertEqual(response.getCode(), "C")
            lock.signal()
        })
        lock.wait()
    }
    
    func testSetTimeout() throws {
        let opts = Conductrics.RequestOptions(nil)
            .setTimeout(timeout:1)
            .setDefault("a-example", "Z")
        let lock = Lock()
        api.select(opts, "a-example", { response in
            XCTAssertEqual(response.getAgent(), "a-example")
            XCTAssertEqual(response.getPolicy(), Conductrics.Policy.None)
            XCTAssertEqual(response.getCode(), "Z")
            lock.signal()
        })
        lock.wait()
    }
    
    func testSelectMultipleWithDefault() throws {
        let opts = Conductrics.RequestOptions(nil)
            .setDefault("a-invalid", "Z");
        let lock = Lock()
        let agents = [ "a-example", "a-invalid" ]
        api.select(opts, agents, { map in
            for agent in agents {
                let response = map[agent]
                XCTAssertNotNil(response, "Agent: "+agent+" should not have nil response")
                if let response = response {
                    if agent == "a-invalid" {
                        XCTAssertEqual(response.getCode(), "Z");
                        XCTAssertEqual(response.getPolicy(), Conductrics.Policy.None)
                    } else if agent == "a-example" {
                        XCTAssertEqual(response.getPolicy(), Conductrics.Policy.Random)
                    }
                }
            }
            lock.signal()
        })
        lock.wait()
    }
    
    func testSelectMultipleWithForced() throws {
        let opts = Conductrics.RequestOptions(nil)
            .forceOutcome("a-example", "Z");
        let lock = Lock()
        let agents = [ "a-example", "a-invalid" ]
        api.select(opts, agents, { map in
            for agent in agents {
                let response = map[agent]
                XCTAssertNotNil(response, "Agent: "+agent+" should not have nil response")
                if let response = response {
                    if agent == "a-invalid" {
                        XCTAssertEqual(response.getCode(), "A");
                        XCTAssertEqual(response.getPolicy(), Conductrics.Policy.None)
                    } else if agent == "a-example" {
                        XCTAssertEqual(response.getCode(), "Z")
                        XCTAssertEqual(response.getPolicy(), Conductrics.Policy.None)
                    }
                }
            }
            lock.signal()
        })
        lock.wait()
    }
}
