
import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: ViewModel

    var body: some View {
        VStack {
            Text("Set your Disks Free!")

            VStack(alignment: .leading) {
                ForEach(viewModel.volumes) { volume in
                    Text("\(volume.name)")
                }
            } 
            
        }
        .onAppear {
            viewModel.listVolumes()
        }
        .padding()
    }
}

