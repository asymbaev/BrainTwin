import SwiftUI
import SuperwallKit

struct PaywallView: View {
    var body: some View {
        VStack {
            Text("paywall")
            
            Button {
                Superwall.shared.register(placement: "campaign_trigger")
            } label: {
                Text("Open Paywall")
            }
        }
    }
}

#Preview {
    PaywallView()
}
