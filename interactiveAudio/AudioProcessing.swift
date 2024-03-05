// Import foundational framework for basic functionalities, AVFoundation for handling audio, and SwiftUI for UI elements.
import Foundation
import AVFoundation
import SwiftUI

// Define a class responsible for processing audio. 
// This class adheres to ObservableObject to enable UI updates in SwiftUI based on changes in audio processing results.
class AudioEngineProcessor: ObservableObject {
    // Declare two separate AVAudioEngine instances for playback and analysis to allow for distinct audio processing paths.
    var audioEnginePlayback: AVAudioEngine
    var audioEngineAnalysis: AVAudioEngine
    // AVAudioPlayerNode instances for playing audio. One is used for straightforward playback, and the other is for audio analysis.
    var audioPlayerNode: AVAudioPlayerNode
    var analysisPlayerNode: AVAudioPlayerNode
    // Optional AVAudioFile to hold the audio content to be played and analyzed.
    var audioFile: AVAudioFile?
    // Bandpass filters for isolating specific frequency bands. 
    // These are implemented as AVAudioUnitEQ with a single band each for low and high frequencies.
    var lowBandPassFilter: AVAudioUnitEQ
    var highBandPassFilter: AVAudioUnitEQ
    
    // Published properties for SwiftUI to react to changes. 
    // These represent the processed amplitude values for low and high frequency bands.
    @Published var lowBand: Float = 0.0
    @Published var highBand: Float = 0.0
    
    // Initializer to set up the audio processing environment by initializing components and configuring them.
    init() {
        // Initialize audio engines and player nodes.
        self.audioEnginePlayback = AVAudioEngine()
        self.audioEngineAnalysis = AVAudioEngine()
        self.audioPlayerNode = AVAudioPlayerNode()
        self.analysisPlayerNode = AVAudioPlayerNode()
        // Initialize the bandpass filters with a single band each, which will be configured later for specific frequencies.
        self.lowBandPassFilter = AVAudioUnitEQ(numberOfBands: 1)
        self.highBandPassFilter = AVAudioUnitEQ(numberOfBands: 1)
        
        // Configuration methods for setting up the audio processing chain and loading the audio file.
        setupAudioEnginePlayback()
        setupAudioEngineAnalysis()
        setupLowBandPassFilter()
        setupHighBandPassFilter()
        loadAudioFile()
    }
    
    // Configures the audio engine used for playback. 
    // This involves attaching the audio player node to the engine and connecting it to the engine's main mixer node.
    private func setupAudioEnginePlayback() {
        audioEnginePlayback.attach(audioPlayerNode)
        audioEnginePlayback.connect(audioPlayerNode, to: audioEnginePlayback.mainMixerNode, format: nil)
    }
    
    // Sets up the audio engine for analysis. 
    // This involves attaching the analysis player node and the bandpass filters to the engine,
    // and connecting these components in a manner that allows for audio analysis.
    private func setupAudioEngineAnalysis() {
        audioEngineAnalysis.attach(analysisPlayerNode)
        audioEngineAnalysis.attach(lowBandPassFilter)
        audioEngineAnalysis.attach(highBandPassFilter)
        
        // Define the audio format based on the analysis player node's output. 
        // This ensures compatibility throughout the audio processing chain.
        let audioFormat = analysisPlayerNode.outputFormat(forBus: 0)
        // Connect the analysis player node to both bandpass filters, and then to the engine's main mixer. 
        // This establishes a path for audio to be analyzed and filtered.
        audioEngineAnalysis.connect(analysisPlayerNode, to: lowBandPassFilter, format: audioFormat)
        audioEngineAnalysis.connect(lowBandPassFilter, to: audioEngineAnalysis.mainMixerNode, format: audioFormat)
        audioEngineAnalysis.connect(analysisPlayerNode, to: highBandPassFilter, format: audioFormat)
        audioEngineAnalysis.connect(highBandPassFilter, to: audioEngineAnalysis.mainMixerNode, format: audioFormat)
    }
    
    // Configure the low-frequency bandpass filter by setting its type, frequency, bandwidth, and enabling it.
    private func setupLowBandPassFilter() {
        guard let bandPass = lowBandPassFilter.bands.first else { return }
        bandPass.filterType = .bandPass // Set filter type to bandpass to isolate a specific frequency band.
        bandPass.frequency = 20 // Target frequency for the low band, isolating lower frequencies.
        bandPass.bandwidth = 1 // Bandwidth around the target frequency, defining the range of frequencies affected.
        bandPass.bypass = false // Ensure the filter is active and not bypassed.
    }
    
    // Similar to the low bandpass filter setup, but targeting a high-frequency range for the high band.
    private func setupHighBandPassFilter() {
        guard let bandPass = highBandPassFilter.bands.first else { return }
        bandPass.filterType = .bandPass
        bandPass.frequency = 2000 // High target frequency for isolating upper frequencies.
        bandPass.bandwidth = 20
        bandPass.bypass = false
    }
    
    // Attempts to load an audio file from the application's resources. 
    // This is crucial for the playback and analysis to have content to process.
    private func loadAudioFile() {
        guard let fileURL = Bundle.main.url(forResource: "01", withExtension: "mp3") else { return }
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            self.audioFile = audioFile // Store the loaded audio file for later use.
        } catch {
            print("Error loading audio file: \(error)") // Error handling for file loading failures.
        }
    }
    
    // Begins audio playback and installs an audio tap for analysis.
    func play() {
        guard let audioFile = audioFile else { return } // Ensure there is an audio file to play.
        
        audioPlayerNode.scheduleFile(audioFile, at: nil, completionHandler: nil) // Schedule the audio file for playback.
        
        installTapAndAnalyze() // Install an audio tap on the output for real-time analysis.
        
        do {
            try audioEnginePlayback.start() // Start the audio engine for playback.
            audioPlayerNode.play() // Begin playing the audio.
        } catch {
            print("Audio Engine failed to start: \(error)") // Error handling for engine start failures.
        }
    }
    
    // Installs an audio tap on the engine's output node. 
    // This tap allows for real-time audio analysis by capturing audio frames and processing them.
    private func installTapAndAnalyze() {
        
        let outputNode = audioEnginePlayback.mainMixerNode // Reference the main mixer node for tapping.
        
        let format = outputNode.outputFormat(forBus: 0) // Define the audio format for the tap based on the output node's current configuration.
        
        // Install the tap with a specific buffer size and format. The closure captures audio frames for analysis.
        outputNode.installTap(onBus: 0, bufferSize: 256, format: format) { (buffer, when) in
            let lowBand = self.calculateAmplitude(buffer: buffer) // Calculate amplitude for low band (reusing method incorrectly, should differentiate low/high).
            let highBand = self.calculateAmplitude(buffer: buffer) // Calculate amplitude for high band (needs differentiation).
            let mappedLowAmplitude = self.mapAmplitude(amplitude: lowBand) // Map amplitude to a usable range for low band.
            let mappedHighAmplitude = self.mapAmplitude(amplitude: highBand) // Map amplitude for high band.
            DispatchQueue.main.async {
                // Update published properties on the main thread to trigger UI updates.
                self.lowBand = mappedLowAmplitude
                self.highBand = mappedHighAmplitude
            }
        }
    }
    
    
    // Calculate the root mean square (RMS) amplitude of the audio signal in the buffer. 
    // This represents the signal's power and is a measure of its loudness.
    private func calculateAmplitude(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 } // Ensure there is float channel data to process.
        
        let channelDataValue = channelData.pointee // Obtain a pointer to the buffer's float channel data.
        // Map the buffer's frame length to an array of float values representing audio samples.
        let channelDataValues = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelDataValue[$0] }
        
        // Calculate the RMS of the audio samples, a measure of the average power of the audio signal.
        let rms = sqrt(channelDataValues.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        return rms // Return the RMS value as a representation of amplitude.
    }
    
    // Map the amplitude value to a range between 0 and 1. 
    // This is useful for normalizing the amplitude for UI representation or further processing.
    private func mapAmplitude(amplitude: Float) -> Float {
        return min(max(amplitude, 0), 1) // Ensure the amplitude is clamped between 0 and 1.
    }
}
