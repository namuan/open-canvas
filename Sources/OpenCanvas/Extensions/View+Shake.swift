import SwiftUI

extension View {
    func shake(isAnimating: Bool, amount: CGFloat = 10, shakesPerSlide: Int = 3) -> some View {
        self.modifier(ShakeModifier(isAnimating: isAnimating, amount: amount, shakesPerSlide: shakesPerSlide))
    }
}

struct ShakeModifier: GeometryEffect {
    var isAnimating: Bool
    var amount: CGFloat
    var shakesPerSlide: Int
    
    var animatableData: CGFloat {
        get { isAnimating ? 1 : 0 }
        set { }
    }
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        if !isAnimating {
            return ProjectionTransform(.identity)
        }
        
        let translation = amount * sin(animatableData * .pi * CGFloat(shakesPerSlide * 2))
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}
