/*
 * Copyright (c) 2015 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Cocoa

class TasksViewController: NSViewController {
    private static var RESOURCES_COLLOQUIAL_NAME: String!
    private static var EXECUTABLE_COLLOQUIAL_NAME: String!
    private static var EXECUTABLE_FILENAME: String!
    private static var EXECUTABLE_EXTENSION: String!
    
    private static var ASSETS_URL_KEY: String = "assets_url"
    
    @objc dynamic var isRunning = false
    var runTask: Process!
    var outputPipe: Pipe!
    
    @IBOutlet weak var outputText: NSTextView!
    @IBOutlet weak var executablePath: NSPathControl!
    @IBOutlet weak var runButton: NSButton!
    @IBOutlet weak var stopButton: NSButton!
    @IBOutlet weak var spinner: NSProgressIndicator!
    
    @IBOutlet weak var resourcesFolderLocationLabel: NSTextField!
    // UserDefaults.standard.set(val, forKey: StateIdentifiers.firstTime.rawValue)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let path = Bundle.main.path(forResource: "variables", ofType: "plist"), let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject] {
            TasksViewController.RESOURCES_COLLOQUIAL_NAME = dict["RESOURCES_COLLOQUIAL_NAME"] as? String
            TasksViewController.EXECUTABLE_COLLOQUIAL_NAME = dict["EXECUTABLE_COLLOQUIAL_NAME"] as? String
            TasksViewController.EXECUTABLE_FILENAME = dict["EXECUTABLE_FILENAME"] as? String
            TasksViewController.EXECUTABLE_EXTENSION = dict["EXECUTABLE_EXTENSION"] as? String
            
            self.resourcesFolderLocationLabel.cell?.title = "\(TasksViewController.RESOURCES_COLLOQUIAL_NAME!) folder location"
            self.executablePath.toolTip = "The path to the \(TasksViewController.RESOURCES_COLLOQUIAL_NAME!) folder"
            self.runButton.toolTip = "Run \(TasksViewController.EXECUTABLE_COLLOQUIAL_NAME!)"
            self.stopButton.toolTip = "Stop running \(TasksViewController.EXECUTABLE_COLLOQUIAL_NAME!)"
        }
        
        if let executableURL = UserDefaults.standard.url(forKey: TasksViewController.ASSETS_URL_KEY){
            self.executablePath.url = executableURL
        }
    }
    
    @IBAction func pathControlAction(_ sender: NSPathControl) {
        guard let executableURL = sender.url  else {
            self.outputText.string = "You must set the path to the \(TasksViewController.RESOURCES_COLLOQUIAL_NAME!) folder in order to run \(TasksViewController.EXECUTABLE_COLLOQUIAL_NAME!)!"
            return
        }
        
        UserDefaults.standard.set(executableURL, forKey: TasksViewController.ASSETS_URL_KEY)
    }
    
    @IBAction func runExecutable(_ sender: AnyObject) {
        outputText.string = ""
        
        guard let executableURL = executablePath.url  else {
            self.outputText.string = "You must set the path to the \(TasksViewController.RESOURCES_COLLOQUIAL_NAME!) folder in order to run \(TasksViewController.EXECUTABLE_COLLOQUIAL_NAME!)!"
            return
        }
        
        let executableLocation = executableURL.path

        var arguments:[String] = []
        arguments.append(executableLocation)
        
        runButton.isEnabled = false
        spinner.startAnimation(self)
        
        runScript(arguments)
    }
    
    @IBAction func stopTask(_ sender:AnyObject) {
        if self.isRunning {
            self.runTask.terminate()
        }
    }
    
    func runScript(_ arguments:[String]) {
        isRunning = true
        
        let taskQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
        
        taskQueue.async {
            guard let path = Bundle.main.path(forResource: TasksViewController.EXECUTABLE_FILENAME, ofType: TasksViewController.EXECUTABLE_EXTENSION) else {
                print("Unable to locate \(TasksViewController.EXECUTABLE_FILENAME!)")
                return
            }
            
            self.runTask = Process()
            self.runTask.launchPath = path
            self.runTask.arguments = arguments
            
            self.runTask.terminationHandler = {
                task in
                DispatchQueue.main.async(execute: {
                    self.runButton.isEnabled = true
                    self.spinner.stopAnimation(self)
                    self.isRunning = false
                })
            }
            
            self.captureStandardOutputAndRouteToTextView(self.runTask)
            self.runTask.launch()
            self.runTask.waitUntilExit()
        }
    }
    
    func captureStandardOutputAndRouteToTextView(_ task: Process) {
        self.outputPipe = Pipe()
        task.standardError = self.outputPipe
        
        self.outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSFileHandleDataAvailable, object: outputPipe.fileHandleForReading, queue: nil) {
            notification in
            
            let output = self.outputPipe.fileHandleForReading.availableData
            let outputString = String(data: output, encoding: String.Encoding.utf8) ?? ""
            
            DispatchQueue.main.async(execute: {
                let previousOutput = self.outputText.string
                let nextOutput = previousOutput + "\n" + outputString
                self.outputText.string = nextOutput
                
                let range = NSRange(location: nextOutput.count, length:0)
                self.outputText.scrollRangeToVisible(range)
            })
            
            self.outputPipe.fileHandleForReading.waitForDataInBackgroundAndNotify()
        }
    }
}
