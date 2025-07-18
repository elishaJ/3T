import SwiftUI

struct CompletedTicketRow: View {
    let ticket: Ticket
    @ObservedObject var viewModel: TicketViewModel
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(ticket.name)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(.secondary)
            
            HStack {
                Text("Time: \(ticket.formattedTime)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    viewModel.toggleTracking(for: ticket)
                }) {
                    Text("Resume")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Resume tracking this ticket")
            }
        }
        .padding(.vertical, 4)
    }
}