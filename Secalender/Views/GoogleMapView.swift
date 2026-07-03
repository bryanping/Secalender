//
//  GoogleMapView.swift
//  Secalender
//
//  Created by Assistant on 2025/1/15.
//

import SwiftUI
import GoogleMaps
import CoreLocation

struct GoogleMapView: UIViewRepresentable {
    @Binding var region: CLLocationCoordinate2D
    @Binding var cameraPosition: GMSCameraPosition?
    var onCameraChange: ((CLLocationCoordinate2D) -> Void)?
    
    func makeUIView(context: Context) -> GMSMapView {
        let camera = cameraPosition ?? GMSCameraPosition.camera(
            withLatitude: region.latitude,
            longitude: region.longitude,
            zoom: 15.0
        )
        let options = GMSMapViewOptions()
        options.camera = camera
        options.frame = .zero
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = true
        mapView.settings.zoomGestures = true
        mapView.settings.scrollGestures = true
        mapView.settings.rotateGestures = true
        mapView.settings.tiltGestures = false
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        // 只有当相机位置真正改变时才动画，避免持续聚焦
        if let camera = cameraPosition {
            // 检查是否与当前相机位置有显著差异（避免微小变化导致持续动画）
            let currentCamera = mapView.camera
            let latDiff = abs(currentCamera.target.latitude - camera.target.latitude)
            let lngDiff = abs(currentCamera.target.longitude - camera.target.longitude)
            let zoomDiff = abs(currentCamera.zoom - camera.zoom)
            
            // 只有当位置差异超过阈值时才动画（约10米或缩放级别变化）
            if latDiff > 0.0001 || lngDiff > 0.0001 || zoomDiff > 0.5 {
                mapView.animate(to: camera)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        private var debounceWorkItem: DispatchWorkItem?
        
        init(_ parent: GoogleMapView) {
            self.parent = parent
        }
        
        // 使用 didChange 仅更新 region，不触发回调（减少频繁更新）
        func mapView(_ mapView: GMSMapView, didChange position: GMSCameraPosition) {
            let coordinate = CLLocationCoordinate2D(
                latitude: position.target.latitude,
                longitude: position.target.longitude
            )
            parent.region = coordinate
            // 不在这里触发 onCameraChange，等待 idleAt
        }
        
        // 使用 idleAt 在用户停止操作后触发回调，并添加 debounce
        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            // 取消之前的 debounce 任务
            debounceWorkItem?.cancel()
            
            let coordinate = CLLocationCoordinate2D(
                latitude: position.target.latitude,
                longitude: position.target.longitude
            )
            
            // 创建 debounce 任务（0.3秒延迟）
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.parent.region = coordinate
                self.parent.onCameraChange?(coordinate)
            }
            
            debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        }
    }
}
