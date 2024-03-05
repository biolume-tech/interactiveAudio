// Import the SwiftUI framework to use its components for creating the user interface.
import SwiftUI

// Define a struct named ContentView, conforming to the View protocol, to design the UI layout.
struct ContentView: View {
    // Declare an @StateObject variable named audioProcessor of type AudioEngineProcessor.
    // This establishes a source of truth for the app's state that can interact with SwiftUI's lifecycle,
    // allowing the UI to react to changes in audio processing.
    @StateObject var audioProcessor = AudioEngineProcessor()
    
    // The body property, a required component of the View protocol, defines the view's content.
    var body: some View {
        // VStack is a vertical stack layout that organizes child views linearly along the vertical axis.
        VStack {
            // Create a button with the title "Play Audio".
            Button("Play Audio") {
                // This closure is executed when the button is tapped, triggering the play function of the audioProcessor.
                audioProcessor.play()
            }
            // Styling for the button with padding, blue background color, white foreground color, and rounded corners.
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .animation(.easeOut, value: audioProcessor.lowBand)
            
            
            // Create a Circle view that visualizes the audio amplitude.
            Circle()
            // The color of the circle is determined by the highBand property of the audioProcessor.
            // The hue parameter of the Color is dynamically bound to the highBand value,
            // with full saturation and brightness, creating a color that changes with the audio's high frequency amplitude.
                .fill(Color(hue: Double(audioProcessor.highBand), saturation: 4.0, brightness: 1.0))
            // Dynamically set the frame of the circle based on the lowBand amplitude, using the mapAmplitudeToSize helper function.
            // This results in the circle's size changing in response to the low frequency amplitude of the audio.
                .frame(width: self.mapAmplitudeToSize(amplitude: audioProcessor.lowBand),
                       height: self.mapAmplitudeToSize(amplitude: audioProcessor.lowBand))
                .padding()
            // Apply an animation to the circle's resizing to create a smooth visual effect as the amplitude changes.
                .animation(.easeOut, value: audioProcessor.lowBand)
        }
    }
    
    // Helper function to map an amplitude value to a size for the circle's width and height.
    private func mapAmplitudeToSize(amplitude: Float) -> CGFloat {
        // Define minimum and maximum sizes for the circle to constrain its growth and shrinkage.
        let minSize: CGFloat = 50 // Minimum circle size to ensure visibility even at low amplitudes.
        let maxSize: CGFloat = 300 // Maximum circle size to limit growth at high amplitudes.
        // Calculate the circle size as a linear interpolation between minSize and maxSize based on the amplitude.
        // This transformation allows the circle size to reflect changes in the audio's amplitude visually.
        return CGFloat(amplitude) * (maxSize - minSize) + minSize
    }
}
