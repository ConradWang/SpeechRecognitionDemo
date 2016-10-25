//
//  ViewController.swift
//  SpeechRecognitionDemo
//
//  Created by Sahand Edrisian on 7/14/16.
//  Copyright © 2016 Sahand Edrisian. All rights reserved.
//

import UIKit
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    /*
     1. SFSpeechRecognizer 利用 RecognitionRequest 生成 RecognitionTask，RecognitionTask 对象告诉你语音识别对象的结果，它也可以删除或者中断任务。
     2. AVAudioEngine 的 inputNode 中的语音信息会传给 RecognitionRequest。
     */
	
	private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
	@IBOutlet weak var textView: UITextView!
	@IBOutlet weak var microphoneButton: UIButton!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
        microphoneButton.isEnabled = false
        speechRecognizer?.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            var isButtonEnabled = false
            
            switch authStatus {
            case .authorized:
                isButtonEnabled = true
                
            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")
                
            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")
                
            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            }
            
            OperationQueue.main.addOperation() {
                self.microphoneButton.isEnabled = isButtonEnabled
            }
        }
	}
    
    // MARK: - SFSpeechRecognizerDelegate
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            microphoneButton.isEnabled = true
        } else {
            microphoneButton.isEnabled = false
        }
    }

    // MARK: - Action
	@IBAction func microphoneTapped(_ sender: AnyObject) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            microphoneButton.isEnabled = false
            microphoneButton.setTitle("Start Recording", for: .normal)
        } else {
            startRecording()
            microphoneButton.setTitle("Stop Recording", for: .normal)
        }
	}
    
    // MARK: - Private methods
    func startRecording() {
        // 检查 recognitionTask 是否在运行。如果在就取消任务和识别。
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // 创建一个 AVAudioSession 来为记录语音做准备。
        // 在这里我们设置session的类别为recording，模式为measurement，然后激活它。
        // 注意设置这些属性有可能会抛出异常，因此你必须把他们放入try catch语句里面。
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties waren't set because of an error.")
        }
        
        // 实例化 recognitionRequest。在这里我们创建了 SFSpeechAudioBufferRecognitionRequest 对象，稍后我们利用它把语音数据传到苹果后台。
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        // 检查 audioEngine（你的设备）是否有做录音功能作为语音输入。如果没有，我们就报告一个错误。
        guard let inputNode = audioEngine.inputNode else {
            fatalError("Audio engine has no input node")
        }
        
        // 检查 recognitionRequest 对象是否被实例化和不是nil。
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        }
        
        // 当用户说话的时候让 recognitionRequest 报告语音识别的部分结果
        recognitionRequest.shouldReportPartialResults = true
        
        // 调用 speechRecognizer 的 recognitionTask 方法来开启语音识别。
        // 这个方法有一个completion handler回调。这个回调每次都会在识别引擎收到输入的时候，完善了当前识别的信息时候，或者被删除或者停止的时候被调用，最后会返回一个最终的文本。
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            var isFinal = false
            
            if result != nil {
                self.textView.text = result?.bestTranscription.formattedString
                isFinal = (result?.isFinal)!
            }
            
            // 如果没有错误或者结果是最终结果，停止 audioEngine(语音输入)并且停止 recognitionRequest 和 recognitionTask。同时，使Start Recording按钮有效。
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.microphoneButton.isEnabled = true
            }
            
        })
        
        // 向 recognitionRequest 增加一个语音输入。注意在开始了 recognitionTask 之后增加语音输入是OK的。Speech Framework 会在语音输入被加入的同时就开始进行解析识别。
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            recognitionRequest.append(buffer)
        }
        
        // 准备并且开始audioEngine。
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
        textView.text = "Say something, I'm listening!"
    }
}

