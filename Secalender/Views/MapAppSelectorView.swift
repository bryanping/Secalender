//
//  MapAppSelectorView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI
import CoreLocation

/// 地图应用选择器视图
struct MapAppSelectorView: View {
    let destination: String
    let coordinate: CLLocationCoordinate2D?
    @Environment(\.dismiss) var dismiss
    
    @State private var availableMapApps: [MapAppType] = []
    
    var body: some View {
        NavigationView {
            List {
                ForEach(availableMapApps, id: \.self) { mapApp in
                    Button(action: {
                        openMapApp(mapApp)
                        dismiss()
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: mapApp.iconName)
                                .foregroundColor(.blue)
                                .font(.title2)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mapApp.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if !mapApp.isInstalled && mapApp != .apple {
                                    Text("map_app_selector.not_installed".localized())
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                } else if mapApp == .apple {
                                    Text("map_app_selector.system_builtin".localized())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("map_app_selector.title".localized())
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadAvailableMapApps()
            }
        }
    }
    
    private func loadAvailableMapApps() {
        availableMapApps = MapAppManager.shared.getAvailableMapApps()
        
        // 如果没有可用的地图应用，至少显示 Apple 地图
        if availableMapApps.isEmpty {
            availableMapApps = [.apple]
        }
    }
    
    private func openMapApp(_ mapApp: MapAppType) {
        MapAppManager.shared.openMapApp(mapApp, destination: destination, coordinate: coordinate)
    }
}

/// 地图应用选择器 Sheet 修饰符
struct MapAppSelectorSheet: ViewModifier {
    @Binding var isPresented: Bool
    let destination: String
    let coordinate: CLLocationCoordinate2D?
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                MapAppSelectorView(destination: destination, coordinate: coordinate)
            }
    }
}

extension View {
    /// 显示地图应用选择器
    func mapAppSelector(isPresented: Binding<Bool>, destination: String, coordinate: CLLocationCoordinate2D? = nil) -> some View {
        modifier(MapAppSelectorSheet(isPresented: isPresented, destination: destination, coordinate: coordinate))
    }
}
