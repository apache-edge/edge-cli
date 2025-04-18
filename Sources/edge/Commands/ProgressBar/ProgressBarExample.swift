import Foundation
import ArgumentParser

/// Example functions demonstrating how to use the ProgressBar
public enum ProgressBarExample {
    
    /// Demonstrates a simple progress bar that updates at a fixed rate
    public static func simpleExample(additionalText: String?) {
        let progressBar = ProgressBar(width: 20)
        
        print("Simple progress bar example:")
        if let text = additionalText {
            print("Additional text: \(text)")
        }
        
        // Simulate progress
        for i in 0...10 {
            let progress = Double(i) / 10.0
            progressBar.update(progress: progress, additionalText: additionalText)
            Thread.sleep(forTimeInterval: 0.2)
        }
        
        progressBar.complete(message: "Completed!")
    }
    
    /// Demonstrates a progress bar with custom characters
    public static func customExample(additionalText: String?) {
        let progressBar = ProgressBar(
            width: 20,
            filledChar: "#",
            emptyChar: "-",
            leftBracket: "(",
            rightBracket: ")"
        )
        
        print("Custom progress bar example:")
        
        // Simulate progress
        for i in 0...20 {
            let progress = Double(i) / 20.0
            progressBar.update(progress: progress, additionalText: additionalText)
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        progressBar.complete(message: "Completed with custom style!")
    }
    
    /// Demonstrates how to use the progress bar with a real task
    public static func realTaskExample(additionalText: String?) {
        let progressBar = ProgressBar(width: 30)
        let totalItems = 100
        
        print("Processing items:")
        
        // Simulate processing items with variable timing
        for i in 1...totalItems {
            // Simulate work with random duration
            let workDuration = Double.random(in: 0.01...0.05)
            Thread.sleep(forTimeInterval: workDuration)
            
            // Update progress
            let progress = Double(i) / Double(totalItems)
            progressBar.update(progress: progress, additionalText: additionalText)
        }
        
        progressBar.complete(message: "All items processed successfully!")
    }
}

public struct ProgressBarExampleCommand: ParsableCommand {
    public init() {}
    
    public static let configuration = CommandConfiguration(
        commandName: "progress-bar-example",
        abstract: "Example of how to use the ProgressBar"
    )

    public func run() {
        // Just run the simple example without additional text
        ProgressBarExample.simpleExample(additionalText: "Progress bar example")
    }
}