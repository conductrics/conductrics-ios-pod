//
//  Conductrics.swift
//  Conductrics
//
//  Created by Jesse Granger on 6/4/20.
//  Copyright © 2020 Conductrics. All rights reserved.
//

import Foundation

public class Conductrics {

    public enum Status : String {
        case Unknown
        case Provisional
        case Confirmed
    }
    public enum Policy : String {
        case Unknown
        case None
        case Paused
        case Random
        case Fixed
        case Adaptive
        case Control
        case Sticky
        case Bot
    }
    public enum SelectError : Error {
        case Offline
        case Timeout
        case InvalidAgent
    }
    public enum ExecError : Error {
        case Server(message: String)
        case BadStatus(code: uint)
        case Unknown(message: String)
        case Offline
    }

    private var apiUrl : String;
    private var apiKey : String;

    public init( apiUrl : String, apiKey : String ) {
        self.apiKey = apiKey;
        self.apiUrl = apiUrl;
    }

    public class RequestOptions {
        public init( _ sessionID : String?) {
            if let s = sessionID {
                self.session = s;
            } else {
                self.session = UUID().uuidString;
            }
        }
        private var session : String? = nil;
        public func getSession() -> String? { return session; }
        public func setSession(sessionId :  String) -> RequestOptions {
            session = sessionId;
            return self;
        }

        private var provisional : Bool = false;
        public func getProvisional() -> Bool { return provisional; }
        public func setProvisional( _ value : Bool ) -> RequestOptions {
            provisional = value;
            if( value ) {
                shouldConfirm = false;
            }
            return self;
        }

        private var shouldConfirm : Bool = false;
        public func getConfirm() -> Bool { return shouldConfirm; }
        public func setConfirm( _ value : Bool ) -> RequestOptions {
            shouldConfirm = value;
            if( value ) {
                provisional = false;
            }
            return self;
        }

        private var ua : String = "Swift SDK";
        public func getUserAgent() -> String { return self.ua; }
        public func setUserAgent( _ ua : String ) -> RequestOptions {
            self.ua = ua;
            return self;
        }

        private var timeout : Int32 = 1000;
        public func getTimeout()  -> Int32 { return timeout; }
        public func setTimeout( ms : Int32 ) ->  RequestOptions {
            self.timeout = ms;
            return self;
        }

        private var defaultOptions = [String:String]();
        public func getDefault( _ agentCode : String ) -> String { return self.defaultOptions[agentCode] ?? "A"; }
        public func setDefault( _ agentCode : String, _ variant : String ) -> RequestOptions {
            self.defaultOptions[agentCode] = variant;
            return self;
        }

        private var offline = false;
        public func getOffline() -> Bool { return offline; }
        public func setOffline( _ value : Bool) -> RequestOptions {
            offline = value;
            return self;
        }

        private var allowed = [String:[String]]();
        public func setAllowedVariants( _ agentCode : String, variants: [String]) -> RequestOptions {
            allowed[agentCode] = variants;
            return self
        }
        public func getAllowedVariants( _ agentCode : String) -> [String]? {
            return allowed[agentCode];
        }

        private var input = [String:String]();
        public func getInputs() -> [String:String] { return input; }
        public func setInput( _ key : String, _ value : String ) -> RequestOptions {
            input[key] = value;
            return self;
        }
        public func setInput( _ key : String, _ value : UInt64 ) -> RequestOptions {
            input[key] = String(value);
            return self;
        }
        public func setInput( _ key : String, _ value : Float64 ) -> RequestOptions {
            input[key] = String(value);
            return self;
        }
        public func setInput( _ key : String, _ value : Bool ) -> RequestOptions {
            input[key] = String(value);
            return self;
        }

        private var params = [String:String]();
        public func getParams() -> [String:String] {
            return params;
        }
        public func setParam( _ key : String, _ value : String ) -> RequestOptions {
            params[key] = value;
            return self;
        }

        private var traits : Set<String> = Set<String>();
        public func getTraits() -> Set<String> {
            return traits;
        }
        public func setTrait( _ group : String, _ value : String) -> RequestOptions {
            self.traits.insert( group + ":" + value );
            return self;
        }

    }

    private func APIPOST( _ opts : RequestOptions, _ body : String, _ callback: @escaping (String) -> Void ) {
        if var urlParts = URLComponents(string: self.apiUrl) {
            var queryItems = [URLQueryItem]()
            queryItems.append(URLQueryItem(name: "apikey", value: self.apiKey));
            queryItems.append(URLQueryItem(name: "session", value: opts.getSession()))
            for (k, v) in opts.getParams() {
                queryItems.append(URLQueryItem(name: k, value: v))
            }
            let traits = opts.getTraits().joined(separator: ",")
            if traits.count > 0 {
                queryItems.append(URLQueryItem(name: "traits", value: traits));
            }
            urlParts.queryItems = queryItems;
            
            if let apiUrl = urlParts.url {
                var request = URLRequest(url: apiUrl);
                if let utfData : Data = body.data(using: .utf8) {
                    request.httpMethod = "POST";
                    request.httpBody = utfData;
                    request.setValue( "application/json", forHTTPHeaderField: "Content-Type" );
                    request.setValue( String(utfData.count), forHTTPHeaderField: "Content-Length" );
                    // request.setValue( "utf8", forHTTPHeaderField: "Content-Encoding" );
                }
                debugPrint("POST", body, apiUrl);
                request.timeoutInterval = Double(opts.getTimeout()) / 1000.0
                let defaultSession = URLSession(configuration: .default)
                let callback = callback; // get a local copy to capture in the closure
                var task: URLSessionDataTask?
                task = defaultSession.dataTask(with: request) { data, response, error in
                    defer {
                        task = nil;
                    }
                    var _data : String;
                    if let error = error {
                        _data = "{ \"status\": 900, \"error\": \"" + String(describing: error).replacingOccurrences(of: "\"", with: "'") + "\" }";
                    } else if let data = data {
                        // this should be the reguler JSON, or JSON-encoded error, response from the API
                        _data = String(data: data, encoding: .utf8) ?? "";
                    } else if let response = response as? HTTPURLResponse {
                        _data = "{ \"status\": " + String(response.statusCode) + ", \"error\": \"no data\"}";
                    } else {
                        _data = "{ \"status\": 999, \"error\": 'no error and no response object' }";
                    }
                    debugPrint("POST response: " + _data);
                    callback(_data);
                }
                task?.resume();
            }
        }
    }

    public class ExecResponse {
        private var sels : [String:SelectResponse] = [String:SelectResponse]();
        private var rewards : [String:GoalResponse] = [String:GoalResponse]();
        private var traits : [String] = [String]();
        private var fullResponse : [String:Any]?;
        private var opts : RequestOptions;
        private var err : Error?;
        public init( _ opts: RequestOptions, json: String?, err: Error? ) {
            self.opts = opts;
            if let err = err {
                setError(err);
                return;
            }
            // the json comes in like: { items: [], sels: { "a-example" : "A" }, rew: [ { "g-example" : 1 } ] }
            if let json = json {
                do {
                    if let obj = try JSONSerialization.jsonObject( with: Data(json.utf8), options: []) as? [String:Any] {
                        fullResponse = obj;
                        if let err = obj["err"] as? String {
                            debugPrint("Server error", err);
                            setError(ExecError.Server(message:err));
                            return;
                        }
                        if let status = obj["status"] as? uint {
                            if status != 200 {
                                debugPrint("Bad status", status)
                                setError(ExecError.BadStatus(code:status));
                                return;
                            }
                        } else {
                            debugPrint("Missing status")
                            setError(ExecError.Unknown(message:"Missing status in response"));
                            return;
                        }
                        if let data = obj["data"] as? [String:Any] {
                            if let items = data["items"] as? [[String:Any]] {
                                for item in items {
                                    if let a = item["a"] as? String {
                                        self.sels[a] = SelectResponse(item, parent: self);
                                    }
                                    else if let g = item["g"] as? String {
                                        self.rewards[g] = GoalResponse(item, parent: self);
                                    }
                                }
                            }
                            if let traits = data["traits"] as? [String] {
                                self.traits = traits;
                            }
                        } else {
                            setError(ExecError.Unknown(message: "No data key in JSON response."));
                            return;
                        }
                    } else {
                        setError(ExecError.Unknown(message: "Failed to parse response as JSON: " + json));
                        return;
                    }
                    
                } catch {
                    debugPrint("caught error in ExecResponse():", error);
                    debugPrint("using json:", json);
                    setError(error);
                    return;
                }
            }
        }
        public func setError( _ err: Error ) {
            if self.err == nil {
                self.err = err;
            }
        }
        public func getError() -> Error? { return self.err; }

        public func getLog() -> [String]? {
            if let data = fullResponse?["data"] as? [String:Any] {
                return data["log"] as? [String];
            }
            return nil;
        }

        public func getSelection( _ agentCode : String ) -> SelectResponse {
            if let sel = sels[agentCode] {
                return sel;
            } else {
                let sel = SelectResponse(agentCode, opts.getDefault(agentCode), Policy.None,
                                         err: SelectError.InvalidAgent, parent: self);
                sels[agentCode] = sel;
                return sel;
            }
        }
        public func getReward( _ goalCode : String ) -> GoalResponse {
            return rewards[goalCode] ?? GoalResponse(goalCode, parent: self);
        }
        public func getTraits() -> [String] {
            return traits;
        }
        public func getJSON() -> [String:Any]? {
            return fullResponse;
        }
    }
    public func exec( _ opts : RequestOptions, _ commands: [[String:Any]], _ callback : @escaping (ExecResponse) -> Void ) {
        if opts.getOffline() {
            callback(ExecResponse(opts, json:nil, err:ExecError.Offline));
        } else {
            do {
                var root = [String:Any]();
                root["commands"] = commands;
                let inputs = opts.getInputs()
                if inputs.count > 0 {
                    root["inputs"] = inputs;
                }
                let data : Data = try JSONSerialization.data(withJSONObject: root, options: [])
                let body : String = String(data:data, encoding: .utf8) ?? "{}"
                APIPOST( opts, body, { resp_body in
                    callback(ExecResponse(opts, json:resp_body, err:nil));
                });
            } catch {
                debugPrint("caught error in exec()", error);
                callback(ExecResponse(opts, json:nil, err:error));
            }
        }
    }

    public class SelectResponse {
        private var agentCode : String = "unknown";
        private var optionCode : String = "A";
        private var policy : Policy = Policy.Unknown;
        private var status : Status = Status.Unknown;
        private var metadata : [String:String] = [String:String]();
        private var jsonObject : [String:Any]?;
        private var error : Error?;
        private var parent : ExecResponse?;
        public init( _ json: [String:Any], parent: ExecResponse? ) {
            self.parent = parent;
            jsonObject = json;
            if let a = json["a"] as? String {
                agentCode = a;
            }
            if let c = json["c"] as? String {
                optionCode = c;
            }
            if let p = json["p"] as? String {
                switch p {
                case "x": policy = Policy.None;
                case "p": policy = Policy.Paused;
                case "r": policy = Policy.Random;
                case "f": policy = Policy.Fixed;
                case "a": policy = Policy.Adaptive;
                case "c": policy = Policy.Control;
                case "s": policy = Policy.Sticky;
                case "b": policy = Policy.Bot;
                default: policy = Policy.Unknown;
                }
            }
            if let s = json["s"] as? String {
                switch( s ) {
                case "p": status = Status.Provisional;
                case "ok": status = Status.Confirmed;
                default: status = Status.Unknown;
                }
            }
            if let md = json["md"] as? [String:String] {
                for (k,v) in md {
                    metadata[k] = v;
                }
            }
        }
        public init( _ a: String, _ c: String, _ p: Policy, err: Error?, parent: ExecResponse? ) {
            agentCode = a;
            optionCode = c;
            policy = p;
            status = Status.Unknown;
            jsonObject = nil;
            error = err;
            self.parent = parent;
        }
        public func getMeta(_ key : String) -> String? { return metadata[key]; }
        public func getAgent() -> String { return agentCode; }
        public func getCode() -> String { return optionCode; }
        public func getPolicy() -> Policy { return policy; }
        public func getStatus() -> Status { return status; }
        public func getJSON() -> [String:Any]? { return jsonObject; }
        public func getExecResponse() -> ExecResponse? { return parent; }
        public func getError() -> Error? { return error; }
        public func getTraits() -> [String]? { return getExecResponse()?.getTraits(); }
    }
    public func select( _ opts : RequestOptions, _ agentCode : String, _ callback : @escaping (SelectResponse) -> Void ) {
        var commands = [[String:Any]]();
        var command : [String:Any] =  ["a": agentCode];
        if opts.getOffline() {
            callback(SelectResponse(agentCode, opts.getDefault(agentCode), Policy.None,
                                    err: SelectError.Offline,
                                    parent: nil))
            return;
        }
        if( opts.getProvisional() ) {
            command["s"] = "p";
        } else if( opts.getConfirm() ) {
            command["s"] = "ok";
        }
        if let allowed = opts.getAllowedVariants(agentCode) {
            command["c"] = allowed;
        }
        commands.append(command);
        exec( opts, commands, { response in
            callback(response.getSelection(agentCode));
        })
    }
    public func select( _ opts: RequestOptions, _ agents : [String],
                        _ callback : @escaping ([String:SelectResponse]) -> Void ) {
        var commands = [[String:Any]]();
        var ret = [String:SelectResponse]()
        for agent in agents {
            if opts.getOffline() {
                ret[agent] = SelectResponse(agent, opts.getDefault(agent), Policy.None, err: SelectError.Offline, parent:nil);
            } else {
                var command = [ "a": agent ]
                if( opts.getProvisional() ) {
                    command["s"] = "p";
                } else if( opts.getConfirm() ) {
                    command["s"] = "ok";
                }
                /*
                if let forced = opts.getForcedOutcome(agent) {
                    ret[agent] = SelectResponse(agent, forced, Policy.None, err: SelectError.Forced, parent:nil)
                } else {
                    commands.append(command)
                }
                */
                commands.append(command)
            }
        }
        if opts.getOffline() {
            callback(ret)
        } else {
            exec( opts, commands, { response in
                for agent in agents {
                    if ret[agent] == nil {
                        ret[agent] = response.getSelection(agent)
                    }
                }
                callback(ret);
            })
        }
    }

    public class GoalResponse {
        private var goal : String = "none";
        private var accepted : [String:Double] = [String:Double]();
        private var jsonObject : [String:Any]?;
        private var parent : ExecResponse?;
        public init( _ goalCode: String, parent: ExecResponse? ) {
            self.parent = parent;
            self.goal = goalCode;
            self.jsonObject = nil;
        }
        public init( _ json: [String:Any], parent: ExecResponse? ) {
            self.parent = parent;
            jsonObject = json;
            if let g = json["g"] as? String {
                self.goal = g;
                if let rs = json["rs"] as? [[String:Any]] {
                    for item in rs {
                        if let agentCode = item["a"] as? String {
                            if let acceptedValue = item["v"] as? Double {
                                accepted[agentCode] = acceptedValue;
                            }
                        }
                    }
                }
            }
        }
        public func getGoalCode() -> String { return goal; }
        public func getAcceptedValue( agentCode : String ) -> Double {
            return accepted[agentCode] ?? 0.0;
        }
        public func getJSON() -> [String:Any]? { return jsonObject; }
        public func getExecResponse() -> ExecResponse? { return parent; }
    }
    public func reward( _ opts : RequestOptions, _ goalCode: String, value: Double, _ callback: @escaping (GoalResponse) -> Void ) {
        if opts.getOffline() {
            callback(GoalResponse(goalCode, parent: nil));
        } else {
            let commands : [[String:Any]] = [ ["g": goalCode, "v": 1.0] ];
            exec( opts, commands, { response in
                callback(response.getReward(goalCode));
            })
        }
    }
    public func reward( _ opts : RequestOptions, _ goalCode: String, _ callback: @escaping (GoalResponse) -> Void ) {
        self.reward(opts, goalCode, value: 1.0, callback);
    }
}
