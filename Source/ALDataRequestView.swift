//
//  ALDataRequestView.swift
//  Pods
//
//  Created by Antoine van der Lee on 28/02/16.
//
//

import UIKit
import PureLayout
import ReachabilitySwift

public typealias RetryAction = (() -> Void)

public enum RequestState {
    case Possible
    case Loading
    case Failed
    case Success
    case Empty
}

public enum ReloadReason {
    case GeneralError
    case NoInternetConnection
}

public protocol Emptyable {
    var isEmpty:Bool { get }
}

public protocol ALDataReloadType {
    var retryButton:UIButton! { get set }
    func setupForReloadType(reloadType:ReloadReason)
}

public protocol ALDataRequestViewDataSource : class {
    func loadingViewForDataRequestView(dataRequestView: ALDataRequestView) -> UIView
    func reloadViewControllerForDataRequestView(dataRequestView: ALDataRequestView) -> ALDataReloadType
    func emptyViewForDataRequestView(dataRequestView: ALDataRequestView) -> UIView
}

public class ALDataRequestView: UIView {

    // Public properties
    public var dataSource:ALDataRequestViewDataSource?
    
    /// Action for retrying a failed situation
    /// Will be triggered by the retry button, on foreground or when reachability changed to connected
    public var retryAction:RetryAction?
    
    /// If failed earlier, the retryAction will be triggered on foreground
    public var automaticallyRetryOnForeground:Bool = true
    
    /// If failed earlier, the retryAction will be triggered when reachability changed to reachable
    public var automaticallyRetryWhenReachable:Bool = true
    
    // Internal properties
    internal var state:RequestState = .Possible
    
    // Private properties
    private var loadingView:UIView?
    private var reloadView:UIView?
    private var emptyView:UIView?
    private var reachability:Reachability?

    override public func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    internal func setup(){
        initOnForegroundObserver()
        initReachabilityMonitoring()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: Public Methods
    public func changeRequestState(state:RequestState){
        guard state != self.state else { return }
        
        self.state = state
        
        switch state {
        case .Possible:
            resetToPossibleState()
            hidden = true
            break
        case .Loading:
            resetToPossibleState()
            showLoadingView()
            hidden = false
            break
        case .Failed:
            resetToPossibleState()
            showReloadView()
            hidden = false
            break
        case .Success:
            resetToPossibleState()
            hidden = true
            break
        case .Empty:
            resetToPossibleState()
            showEmptyView()
            hidden = false
            break
        }
    }
    
    // MARK: Private Methods
    
    /// This will remove all views added
    private func resetToPossibleState(){
        loadingView?.removeFromSuperview()
        emptyView?.removeFromSuperview()
        reloadView?.removeFromSuperview()
    }
    
    /// This will show the loading view
    internal func showLoadingView(){
        guard let dataSourceLoadingView = dataSource?.loadingViewForDataRequestView(self) else {
            debugLog("No loading view provided!")
            return
        }
        
        loadingView = dataSourceLoadingView
        addSubview(loadingView!)
        loadingView?.autoPinEdgesToSuperviewEdges()
    }
    
    /// This will show the reload view
    internal func showReloadView(){
        guard let dataSourceReloadType = dataSource?.reloadViewControllerForDataRequestView(self) else {
            debugLog("No reload view provided!")
            return
        }
        
        if let dataSourceReloadView = dataSourceReloadType as? UIView {
            reloadView = dataSourceReloadView
            
        } else if let dataSourceReloadViewController = dataSourceReloadType as? UIViewController {
            reloadView = dataSourceReloadViewController.view
        }
        
        guard let reloadView = reloadView else {
            debugLog("Could not determine reloadView")
            return
        }
        
        addSubview(reloadView)
        reloadView.autoPinEdgesToSuperviewEdges()
        dataSourceReloadType.setupForReloadType(ReloadReason.GeneralError)
        dataSourceReloadType.retryButton.addTarget(self, action: "retryButtonTapped:", forControlEvents: UIControlEvents.TouchUpInside)
        
    }
    
    /// This will show the empty view
    internal func showEmptyView(){
        guard let dataSourceEmptyView = dataSource?.emptyViewForDataRequestView(self) else {
            debugLog("No loading view provided!")
            return
        }
        
        emptyView = dataSourceEmptyView
        addSubview(emptyView!)
        emptyView?.autoPinEdgesToSuperviewEdges()
    }
    
    /// IBAction for the retry button
    @objc private func retryButtonTapped(button:UIButton){
        retryIfRetryable()
    }
    
    /// This will trigger the retryAction if current state is failed
    private func retryIfRetryable(){
        guard state == RequestState.Failed else {
            return
        }
        
        guard let retryAction = retryAction else {
            debugLog("No retry action provided")
            return
        }
        
        retryAction()
    }
}

/// On foreground Observer methods.
private extension ALDataRequestView {
    func initOnForegroundObserver(){
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "onForeground:", name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    @objc private func onForeground(notification:NSNotification){
        guard automaticallyRetryOnForeground == true else {
            return
        }
        retryIfRetryable()
    }
}

/// Reachability methods 
private extension ALDataRequestView {
    
    func initReachabilityMonitoring(){
        do {
            reachability = try Reachability.reachabilityForInternetConnection()
        } catch {
            debugLog("Unable to create Reachability")
            return
        }
        
        reachability?.whenReachable = { reachability in
            guard self.automaticallyRetryWhenReachable == true else {
                return
            }
            
            self.retryIfRetryable()
        }
        
        do {
            try reachability?.startNotifier()
        } catch {
            debugLog("Unable to start notifier")
        }
    }
}

/// Logging purposes
private extension ALDataRequestView {
    func debugLog(logString:String){
        print("ALDataRequestView: \(logString)")
    }
}