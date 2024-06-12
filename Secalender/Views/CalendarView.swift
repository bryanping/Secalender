//
//  CalendarView.swift
//  Secalender
//
//  Created by linping on 2024/6/24.
//

import SwiftUI
//import FirebaseFirestore

struct CalendarView: View {
    
//    @State private var events: [Event] = []
//    @State private var dataLoaded = false
//
//    private var db = Firestore.firestore()

    var body: some View {
       
            Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)

//        NavigationView {
//            if dataLoaded && events.isEmpty {
//                Text("No events available")
//                    .font(.title)
//                    .foregroundColor(.gray)
//            } else {
//                List {
//                    ForEach(events, id: \.id) { event in
//                        NavigationLink(destination: EventDetailView(event: event)) {
//                            Text(event.title)
//                        }
//                    }
//                }
//                .onAppear(perform: fetchEvents)
//                .navigationBarTitle("行事历")
//            }
//        }
    }

//    private func fetchEvents() {
//        db.collection("events").getDocuments { querySnapshot, error in
//            if let querySnapshot = querySnapshot {
//                events = querySnapshot.documents.compactMap { document in
//                    try? document.data(as: Event.self)
//                }
//            }
//            dataLoaded = true
//        }
//    }
}

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView()
    }
}

