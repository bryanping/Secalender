//
//  NearbyEventsView.swift
//  Secalender
//
//  Created by 林平 on 2025/5/29.
//

import SwiftUI
import MapKit

struct NearbyEventsView: View {
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 25.0330, longitude: 121.5654), // 台北市中心
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    var body: some View {
        VStack {
            Map(coordinateRegion: $region, interactionModes: [.all], showsUserLocation: true)
                .edgesIgnoringSafeArea(.all)
        }
    }
}
