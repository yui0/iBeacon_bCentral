//
//  ViewController.m
//  bCentral
//
//  Created by Yuichiro Nakada on 2016/09/09.
//  Copyright © 2016 Yuichiro Nakada. All rights reserved.
//

#import "ViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <AudioToolbox/AudioServices.h>
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMessageComposeViewController.h>

#define UUID        @"7485B0B6-7596-48D5-92EB-B1E1EB67563C"
#define IDENTIFIER  @"jp.yui.region"

@interface ViewController () <CLLocationManagerDelegate, MFMessageComposeViewControllerDelegate>

@property (nonatomic) CLLocationManager *locationManager;
@property (nonatomic) CLBeaconRegion *beaconRegion;

@property (nonatomic) NSUUID *proximityUUID;
@property (strong, nonatomic) NSString *identifier;
@property uint16_t major;
@property uint16_t minor;

@property (weak, nonatomic) IBOutlet UILabel *beaconFoundLabel;
@property (weak, nonatomic) IBOutlet UILabel *proximityUUIDLabel;
@property (weak, nonatomic) IBOutlet UILabel *majorLabel;
@property (weak, nonatomic) IBOutlet UILabel *minorLabel;
@property (weak, nonatomic) IBOutlet UILabel *accuracyLabel;
@property (weak, nonatomic) IBOutlet UILabel *distanceLabel;
@property (weak, nonatomic) IBOutlet UILabel *rssiLabel;

@property (weak, nonatomic) IBOutlet UITextView *tvdisply;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    if ([CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]]) {
        // CLLocationManagerの生成とデリゲートの設定
        self.locationManager = CLLocationManager.new;
        self.locationManager.delegate = self;

        // 生成したUUIDからNSUUIDを作成
        self.proximityUUID      = [[NSUUID alloc]initWithUUIDString:UUID];
        self.identifier         = IDENTIFIER;
        self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:self.proximityUUID identifier:self.identifier];

        self.beaconRegion.notifyOnEntry               = YES; // 領域に入った事を監視
        self.beaconRegion.notifyOnExit                = YES; // 領域を出た事を監視
        self.beaconRegion.notifyEntryStateOnDisplay   = YES; // デバイスのディスプレイがオンのとき、ビーコン通知が送信されない
        
        // for iOS8
        // 位置情報の取得許可を求めるメソッド
        if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
            // requestAlwaysAuthorizationメソッドが利用できる場合(iOS8以上の場合)
            // 位置情報の取得許可を求めるメソッド
            [self.locationManager requestAlwaysAuthorization];
        } else {
            // requestAlwaysAuthorizationメソッドが利用できない場合(iOS8未満の場合)
            [self.locationManager startMonitoringForRegion: self.beaconRegion];
        }
        // Beaconによる領域観測を開始
        //[self.locationManager startMonitoringForRegion:self.beaconRegion];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - CLLocationManagerDelegate methods

/*- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
	[self.locationManager startMonitoringForRegion: self.beaconRegion];
}*/

- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region
{
	[self sendLocalNotificationForMessage:@"Start Monitoring..."];
}

// 領域に入った時
- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
	// ローカル通知
	[self sendLocalNotificationForMessage:@"Enter Region"];
	AudioServicesPlaySystemSound(1000);

	// SMS送信
	self.displaySMSComposerSheet;
/*	// http://conol.co.jp/blog/archives/47
	Class mail = (NSClassFromString(@"MFMailComposeViewController"));
	if (mail != nil) {
		if ([mail canSendMail]) {
			MFMailComposeViewController *mailPicker = MFMailComposeViewController.new;
			mailPicker.mailComposeDelegate = self;
			[mailPicker setSubject:@"件名"];
			[mailPicker setMessageBody:@"本文" isHTML:NO];
			[self presentModalViewController:mailPicker animated:YES];
		} else {
			// メール設定がされていない場合
		}
	}*/

	// Beaconの距離測定を開始する
	if ([region isMemberOfClass:[CLBeaconRegion class]] && [CLLocationManager isRangingAvailable]) {
		[self.locationManager startRangingBeaconsInRegion:(CLBeaconRegion *)region];
	}
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
	// Beaconの距離測定を終了する
	if ([region isMemberOfClass:[CLBeaconRegion class]] && [CLLocationManager isRangingAvailable]) {
		[self.locationManager stopRangingBeaconsInRegion:(CLBeaconRegion *)region];
	}

	// ローカル通知
	[self sendLocalNotificationForMessage:@"Exit Region"];
	AudioServicesPlaySystemSound(1001);
}

// メソッドの２番目の引数には、距離測定中の Beacon の配列が渡されてきます。この配列は、Beacon までの距離が近い順にソートされていますので、先頭に格納されている CLBeacon のインスタンスが最も距離が近い Beacon の情報となります
// Beacon距離観測 定期的イベント発生（距離の測定を開始）
- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
	if (beacons.count > 0) {
		// 最も距離の近いBeaconについて処理する
		CLBeacon *nearestBeacon = beacons.firstObject;

		// Beacon の距離でメッセージを変える
		NSString *rangeMessage;
		switch (nearestBeacon.proximity) {
		case CLProximityImmediate:
			rangeMessage = @"より近い\n ";
			self.distanceLabel.text = @"より近い";
			break;
		case CLProximityNear:
			rangeMessage = @"近い\n ";
			self.distanceLabel.text = @"近い";
			break;
		case CLProximityFar:
			rangeMessage = @"遠い\n ";
			self.distanceLabel.text = @"遠い";
			break;
		default:
			rangeMessage = @"測距エラー\n ";
			self.distanceLabel.text = @"測距エラー";
		}

		//-------------------------------------------------------------
		// iBeaconの電波強度を調べて、近距離に来た場合
		if (nearestBeacon.proximity == CLProximityImmediate && nearestBeacon.rssi > -40) {
			self.distanceLabel.text   = @"よりより近い";
		}

		self.beaconFoundLabel.text = @"Yes";
		// UUID
		self.proximityUUIDLabel.text = self.beaconRegion.proximityUUID.UUIDString;
		// メジャー
		self.majorLabel.text = [NSString stringWithFormat:@"製品 %@", nearestBeacon.major];
		// マイナー
		self.minorLabel.text = [NSString stringWithFormat:@"分類 %@", nearestBeacon.minor];
		// 距離・精度
		self.accuracyLabel.text = [NSString stringWithFormat:@"%f", nearestBeacon.accuracy];
		// RSSI:電波強度
		self.rssiLabel.text = [NSString stringWithFormat:@"%li", (long)nearestBeacon.rssi];

		[self.tvdisply.text stringByAppendingFormat:@"メジャー:%@,\n マイナー:%@,\n 距離:%f,\n 感度:%ld\n",
			nearestBeacon.major, nearestBeacon.minor, nearestBeacon.accuracy, (long)nearestBeacon.rssi];

		// ローカル通知
/*		NSString *message = [NSString stringWithFormat:@"メジャー:%@,\n マイナー:%@,\n 距離:%f,\n 感度:%ld\n",
					nearestBeacon.major, nearestBeacon.minor, nearestBeacon.accuracy, (long)nearestBeacon.rssi];
		[self sendLocalNotificationForMessage:[rangeMessage stringByAppendingString:message]];*/
	}
}

// iOS8 ユーザの位置情報の許可状態を確認するメソッド
- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
	if (status == kCLAuthorizationStatusNotDetermined) {
		// ユーザが位置情報の使用を許可していない
	} else if(status == kCLAuthorizationStatusAuthorizedAlways) {
		// ユーザが位置情報の使用を常に許可している場合
		[self.locationManager startMonitoringForRegion: self.beaconRegion];
	} else if(status == kCLAuthorizationStatusAuthorizedWhenInUse) {
		// ユーザが位置情報の使用を使用中のみ許可している場合
		[self.locationManager startMonitoringForRegion: self.beaconRegion];
	}
}

/*- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error
{
	[self sendLocalNotificationForMessage:@"Exit Region"];
}*/

#pragma mark - Private methods

- (void)sendLocalNotificationForMessage:(NSString *)message
{
	UILocalNotification *localNotification = UILocalNotification.new;
	localNotification.alertBody = message;
	localNotification.fireDate = [NSDate date];
	localNotification.soundName = UILocalNotificationDefaultSoundName;
	[[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
}

// Displays an SMS composition interface inside the application. 
-(void)displaySMSComposerSheet {
	// シミュレータでは SMS が起動しない
	if (![MFMessageComposeViewController canSendText]) return;

	MFMessageComposeViewController *picker = MFMessageComposeViewController.new;
	picker.messageComposeDelegate = self;

	picker.body = [NSString stringWithUTF8String:"ごはんですよ〜。"];
	picker.recipients = [NSArray arrayWithObjects:@"090-xxxx-xxxx", nil];

	[self presentViewController:picker animated:YES completion:nil];
}
- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result {
	[self dismissViewControllerAnimated:YES completion:nil];
}

@end
