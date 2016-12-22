//
//  ViewController.swift
//  Dumbledore
//
//  Created by Sumedha Pramod on 12/21/16.
//  Copyright © 2016 Sumedha Pramod. All rights reserved.
//

import UIKit

class ViewController: UIViewController, OEEventsObserverDelegate, AVSpeechSynthesizerDelegate {
    
    var slt = Slt()
    var openEarsEventsObserver = OEEventsObserver()
    
    var speechSynthesizer = AVSpeechSynthesizer()
    
    var usingStartingLanguageModel = Bool()
    var startupFailedDueToLackOfPermissions = Bool()
    var restartAttemptsDueToPermissionRequests = Int()
    var pathToFirstDynamicallyGeneratedLanguageModel: String!
    var pathToFirstDynamicallyGeneratedDictionary: String!
    var pathToSecondDynamicallyGeneratedLanguageModel: String!
    var pathToSecondDynamicallyGeneratedDictionary: String!
    var timer: Timer!
    
    @IBOutlet var stopButton:UIButton!
    @IBOutlet var startButton:UIButton!
    @IBOutlet var statusTextView:UITextView!
    @IBOutlet var heardTextView:UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.speechSynthesizer.delegate = self
        self.openEarsEventsObserver.delegate = self
        self.restartAttemptsDueToPermissionRequests = 0
        self.startupFailedDueToLackOfPermissions = false
        
        let languageModelGenerator = OELanguageModelGenerator()
        
        let firstLanguageArray = ["hi", "hello"]
        let dumbledoreVocabName = "DumbledoreVocab"
        
        // OELogging.startOpenEarsLogging()
        
        let firstLanguageModelGenerationError: Error! = languageModelGenerator.generateLanguageModel(from: firstLanguageArray, withFilesNamed: dumbledoreVocabName, forAcousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish")) // Change "AcousticModelEnglish" to "AcousticModelSpanish" in order to create a language model for Spanish recognition instead of English.
        
        if(firstLanguageModelGenerationError != nil) {
            print("Error while creating initial language model: \(firstLanguageModelGenerationError)")
        } else {
            self.pathToFirstDynamicallyGeneratedLanguageModel = languageModelGenerator.pathToSuccessfullyGeneratedLanguageModel(withRequestedName: dumbledoreVocabName) // these are convenience methods you can use to reference the file location of a language model that is known to have been created successfully.
            self.pathToFirstDynamicallyGeneratedDictionary = languageModelGenerator.pathToSuccessfullyGeneratedDictionary(withRequestedName: dumbledoreVocabName) // these are convenience methods you can use to reference the file location of a dictionary that is known to have been created successfully.
            self.usingStartingLanguageModel = true // Just keeping track of which model we're using.
        }
    }
    
    func pocketsphinxDidReceiveHypothesis(_ hypothesis: String!, recognitionScore: String!, utteranceID: String!) {
        print("Local callback: The received hypothesis is \(hypothesis!) with a score of \(recognitionScore!) and an ID of \(utteranceID!)") // Log it.
        
        self.heardTextView.text = "Heard: \"\(hypothesis!)\""
        
        let speechUtterance = AVSpeechUtterance(string: hypothesis)
        self.speechSynthesizer.speak(speechUtterance)
    }
    
    // An optional delegate method of OEEventsObserver which informs that the interruption to the audio session ended.
    func audioSessionInterruptionDidEnd() {
        print("Local callback:  AudioSession interruption ended.") // Log it.
        self.statusTextView.text = "Status: AudioSession interruption ended." // Show it in the status box.
        // We're restarting the previously-stopped listening loop.
        if(!OEPocketsphinxController.sharedInstance().isListening){
            OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false)
            
        }
    }
    
    // An optional delegate method of OEEventsObserver which informs that the audio input became unavailable.
    func audioInputDidBecomeUnavailable() {
        print("Local callback:  The audio input has become unavailable") // Log it.
        self.statusTextView.text = "Status: The audio input has become unavailable" // Show it in the status box.
        
        if(OEPocketsphinxController.sharedInstance().isListening){
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening() // React to it by telling Pocketsphinx to stop listening since there is no available input (but only if we are listening).
            if(stopListeningError != nil) {
                print("Error while stopping listening in audioInputDidBecomeUnavailable: \(stopListeningError)")
            }
        }
        
        // An optional delegate method of OEEventsObserver which informs that the unavailable audio input became available again.
        func audioInputDidBecomeAvailable() {
            print("Local callback: The audio input is available") // Log it.
            self.statusTextView.text = "Status: The audio input is available" // Show it in the status box.
            if(!OEPocketsphinxController.sharedInstance().isListening) {
                OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
            }
        }
        
        // An optional delegate method of OEEventsObserver which informs that there was a change to the audio route (e.g. headphones were plugged in or unplugged).
        func audioRouteDidChange(toRoute newRoute: String!) {
            print("Local callback: Audio route change. The new audio route is \(newRoute)") // Log it.
            self.statusTextView.text = "Status: Audio route change. The new audio route is \(newRoute)"// Show it in the status box.
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening() // React to it by telling Pocketsphinx to stop listening since there is no available input (but only if we are listening).
            if(stopListeningError != nil) {
                print("Error while stopping listening in audioInputDidBecomeAvailable: \(stopListeningError)")
            }
        }
        
        if(!OEPocketsphinxController.sharedInstance().isListening) {
            OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
        }
    }
    
    // An optional delegate method of OEEventsObserver which informs that the Pocketsphinx recognition loop has entered its actual loop.
    // This might be useful in debugging a conflict between another sound class and Pocketsphinx.
    func pocketsphinxRecognitionLoopDidStart() {
        print("Local callback: Pocketsphinx started.") // Log it.
        self.statusTextView.text = "Status: Pocketsphinx started." // Show it in the status box.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx is now listening for speech.
    func pocketsphinxDidStartListening() {
        
        print("Local callback: Pocketsphinx is now listening.") // Log it.
        self.statusTextView.text = "Status: Pocketsphinx is now listening." // Show it in the status box.
        
        self.startButton.isHidden = true // React to it with some UI changes.
        self.stopButton.isHidden = false
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx detected speech and is starting to process it.
    func pocketsphinxDidDetectSpeech() {
        print("Local callback: Pocketsphinx has detected speech.") // Log it.
        self.statusTextView.text = "Status: Pocketsphinx has detected speech." // Show it in the status box.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx detected a second of silence, indicating the end of an utterance.
    // This was added because developers requested being able to time the recognition speed without the speech time. The processing time is the time between
    // this method being called and the hypothesis being returned.
    func pocketsphinxDidDetectFinishedSpeech() {
        print("Local callback: Pocketsphinx has detected a second of silence, concluding an utterance.") // Log it.
        self.statusTextView.text = "Status: Pocketsphinx has detected finished speech." // Show it in the status box.
    }
    
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx has exited its recognition loop, most
    // likely in response to the OEPocketsphinxController being told to stop listening via the stopListening method.
    func pocketsphinxDidStopListening() {
        print("Local callback: Pocketsphinx has stopped listening.") // Log it.
        self.statusTextView.text = "Status: Pocketsphinx has stopped listening." // Show it in the status box.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx is still in its listening loop but it is not
    // Going to react to speech until listening is resumed.  This can happen as a result of Flite speech being
    // in progress on an audio route that doesn't support simultaneous Flite speech and Pocketsphinx recognition,
    // or as a result of the OEPocketsphinxController being told to suspend recognition via the suspendRecognition method.
    func pocketsphinxDidSuspendRecognition() {
        print("Local callback: Pocketsphinx has suspended recognition.") // Log it.
        self.statusTextView.text = "Status: Pocketsphinx has suspended recognition." // Show it in the status box.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx is still in its listening loop and after recognition
    // having been suspended it is now resuming.  This can happen as a result of Flite speech completing
    // on an audio route that doesn't support simultaneous Flite speech and Pocketsphinx recognition,
    // or as a result of the OEPocketsphinxController being told to resume recognition via the resumeRecognition method.
    func pocketsphinxDidResumeRecognition() {
        print("Local callback: Pocketsphinx has resumed recognition.") // Log it.
        self.statusTextView.text = "Status: Pocketsphinx has resumed recognition." // Show it in the status box.
    }
    
    // An optional delegate method which informs that Pocketsphinx switched over to a new language model at the given URL in the course of
    // recognition. This does not imply that it is a valid file or that recognition will be successful using the file.
    func pocketsphinxDidChangeLanguageModel(toFile newLanguageModelPathAsString: String!, andDictionary newDictionaryPathAsString: String!) {
        
        print("Local callback: Pocketsphinx is now using the following language model: \n\(newLanguageModelPathAsString!) and the following dictionary: \(newDictionaryPathAsString!)")
    }
    
    func pocketSphinxContinuousSetupDidFail(withReason reasonForFailure: String!) { // This can let you know that something went wrong with the recognition loop startup. Turn on [OELogging startOpenEarsLogging] to learn why.
        print("Local callback: Setting up the continuous recognition loop has failed for the reason \(reasonForFailure), please turn on OELogging.startOpenEarsLogging() to learn more.") // Log it.
        self.statusTextView.text = "Status: Not possible to start recognition loop." // Show it in the status box.
    }
    
    func pocketSphinxContinuousTeardownDidFail(withReason reasonForFailure: String!) { // This can let you know that something went wrong with the recognition loop startup. Turn on [OELogging startOpenEarsLogging] to learn why.
        print("Local callback: Tearing down the continuous recognition loop has failed for the reason %, please turn on [OELogging startOpenEarsLogging] to learn more.", reasonForFailure) // Log it.
        self.statusTextView.text = "Status: Not possible to cleanly end recognition loop." // Show it in the status box.
    }
    
    func testRecognitionCompleted() { // A test file which was submitted for direct recognition via the audio driver is done.
        print("Local callback: A test file which was submitted for direct recognition via the audio driver is done.") // Log it.
        if(OEPocketsphinxController.sharedInstance().isListening) { // If we're listening, stop listening.
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in testRecognitionCompleted: \(stopListeningError)")
            }
        }
        
    }
    /** Pocketsphinx couldn't start because it has no mic permissions (will only be returned on iOS7 or later).*/
    func pocketsphinxFailedNoMicPermissions() {
        print("Local callback: The user has never set mic permissions or denied permission to this app's mic, so listening will not start.")
        self.startupFailedDueToLackOfPermissions = true
        if(OEPocketsphinxController.sharedInstance().isListening){
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in pocketsphinxFailedNoMicPermissions: \(stopListeningError). Will try again in 10 seconds.")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10), execute: {
            if(!OEPocketsphinxController.sharedInstance().isListening) {
                OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
            }
        })
    }
    
    // Siri Methods
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        OEPocketsphinxController.sharedInstance().suspendRecognition()
        print("Local callback: Dumbledore has started speaking") // Log it.
        self.statusTextView.text = "Status: Dumbledore has started speaking." // Show it in the status box.
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        OEPocketsphinxController.sharedInstance().resumeRecognition()
        print("Local callback: Dumbledore has finished speaking") // Log it.
        self.statusTextView.text = "Status: Dumbledore has finished speaking." // Show it in the status box.
    }
    
    
    /** The user prompt to get mic permissions, or a check of the mic permissions, has completed with a true or a false result  (will only be returned on iOS7 or later).*/
    
    func micPermissionCheckCompleted(withResult: Bool) {
        if(withResult) {
            
            self.restartAttemptsDueToPermissionRequests += 1
            if(self.restartAttemptsDueToPermissionRequests == 1 && self.startupFailedDueToLackOfPermissions) { // If we get here because there was an attempt to start which failed due to lack of permissions, and now permissions have been requested and they returned true, we restart exactly once with the new permissions.
                
                if(!OEPocketsphinxController.sharedInstance().isListening) {
                    OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
                }
                
                self.startupFailedDueToLackOfPermissions = false
            }
        }
        
    }
    
    @IBAction func stopButtonAction() { // This is the action for the button which shuts down the recognition loop.
        if(OEPocketsphinxController.sharedInstance().isListening){
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in pocketsphinxFailedNoMicPermissions: \(stopListeningError)")
            }
        }
        self.startButton.isHidden = false
        self.stopButton.isHidden = true
    }
    
    @IBAction func startButtonAction() { // This is the action for the button which starts up the recognition loop again if it has been shut down.
        if(!OEPocketsphinxController.sharedInstance().isListening) {
            OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelEnglish"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
        }
        self.startButton.isHidden = true
        self.stopButton.isHidden = false
    }
}

