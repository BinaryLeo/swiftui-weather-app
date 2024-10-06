//
//  ContentView.swift
//  weather-app
//
//  Created by Leonardo Moura on 06/10/24.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack{
            LinearGradient(gradient:Gradient(colors:[.blue, .white]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
            .edgesIgnoringSafeArea(.all)
                           
            
            
            
        }
    }
}

#Preview {
    ContentView()
}
