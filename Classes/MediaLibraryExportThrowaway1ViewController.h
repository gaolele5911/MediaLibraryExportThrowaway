//
//  MediaLibraryExportThrowaway1ViewController.h
//  MediaLibraryExportThrowaway1
//
//  Created by Chris Adamson on 7/16/10.
//  http://www.subfurther.com/
//  Released into the public domain, 7/19/10
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

@interface MediaLibraryExportThrowaway1ViewController : UIViewController <MPMediaPickerControllerDelegate> {
	MPMediaItem *song;
	AVPlayer *player;
	NSTimer *playbackTimer;
	BOOL userIsScrubbing;
	NSURL *exportURL;
}

@property (nonatomic, retain) IBOutlet UIImageView *coverArtView;
@property (nonatomic, retain) IBOutlet UILabel *songLabel;
@property (nonatomic, retain) IBOutlet UILabel *artistLabel;
@property (nonatomic, retain) IBOutlet UIProgressView *exportProgressView;
@property (nonatomic, retain) IBOutlet UIButton *exportButton;

@property (nonatomic, retain) IBOutlet UILabel *fileNameLabel;
@property (nonatomic, retain) IBOutlet UIButton *playPauseButton;
@property (nonatomic, retain) IBOutlet UILabel *playbackTimeLabel;
@property (nonatomic, retain) IBOutlet UISlider *playbackSlider;
@property (nonatomic, retain) IBOutlet UITextView *errorView;

@property (nonatomic, retain) IBOutlet UIImageView *coreAudioIcon;
@property (nonatomic, retain) IBOutlet UILabel *coreAudioCompatibilityLabel;
@property (nonatomic, retain) IBOutlet UIButton *convertToPCMButton;
@property (nonatomic, retain) IBOutlet UILabel *pcmFileSizeLabel;


-(IBAction) handleChooseSongTapped;
-(IBAction) handleExportTapped;
-(IBAction) handlePlayPauseTapped;
-(IBAction) handleSliderValueChanged;
-(IBAction) handleSliderTouchDown;
-(IBAction) handleSliderTouchUp;
-(IBAction) handleConvertToPCMTapped;

@end

