//
//  MediaLibraryExportThrowaway1ViewController.m
//  MediaLibraryExportThrowaway1
//
//  Created by Chris Adamson on 7/16/10.
//  http://www.subfurther.com/
//  Released into the public domain, 7/19/10
//

#import "MediaLibraryExportThrowaway1ViewController.h"
#import <AudioToolbox/AudioToolbox.h>

@implementation MediaLibraryExportThrowaway1ViewController

@synthesize coverArtView;
@synthesize songLabel;
@synthesize artistLabel;
@synthesize exportProgressView;
@synthesize exportButton;

@synthesize fileNameLabel;
@synthesize playPauseButton;
@synthesize playbackTimeLabel;
@synthesize playbackSlider;
@synthesize errorView;

@synthesize coreAudioIcon;
@synthesize coreAudioCompatibilityLabel;
@synthesize convertToPCMButton;
@synthesize pcmFileSizeLabel;

#pragma mark init/dealloc
/*
// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/

- (void)dealloc {
    [super dealloc];
	[exportProgressView release];
	[coverArtView release];
	[songLabel release];
	[artistLabel release];
	
	// TODO: missing a bunch of the new properties here (and playbackTimer)
}


#pragma mark conveniences
NSString* myDocumentsDirectory() {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	return [paths objectAtIndex:0];;
}

void myDeleteFile (NSString* path) {
	if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
		NSError *deleteErr = nil;
		[[NSFileManager defaultManager] removeItemAtPath:path error:&deleteErr];
		if (deleteErr) {
			NSLog (@"Can't delete %@: %@", path, deleteErr);
		}
	}
}

// generic error handler from upcoming "Core Audio" book (thanks, Kevin!)
// if result is nonzero, prints error message and exits program.
static void CheckResult(OSStatus result, const char *operation)
{
	if (result == noErr) return;
	
	char errorString[20];
	// see if it appears to be a 4-char-code
	*(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(result);
	if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4])) {
		errorString[0] = errorString[5] = '\'';
		errorString[6] = '\0';
	} else
		// no, format it as an integer
		sprintf(errorString, "%d", (int)result);
	
	fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
	
	exit(1);
}


#pragma mark vc lifecycle

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/


/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

#pragma mark core audio test
BOOL coreAudioCanOpenURL (NSURL* url) {
	OSStatus openErr = noErr;
	AudioFileID audioFile = NULL;
	openErr = AudioFileOpenURL((CFURLRef) url,
							   kAudioFileReadPermission ,
							   0,
							   &audioFile);
	if (audioFile) {
		AudioFileClose (audioFile);
	}
	return openErr ? NO : YES;
}

-(void) enablePCMConversionIfCoreAudioCanOpenURL: (NSURL*) url {
	BOOL coreAudioCanOpen =  coreAudioCanOpenURL (url);
	coreAudioIcon.hidden = NO;
	coreAudioCompatibilityLabel.text = coreAudioCanOpen ?
		 @"Core Audio can open this file" :@"Core Audio cannot open this file";
	coreAudioCompatibilityLabel.hidden = NO;
	convertToPCMButton.hidden = coreAudioCanOpen ? NO : YES;
}

#pragma mark avplayer stuff
-(void) createPlaybackTimer {
	if (playbackTimer) {
		[playbackTimer invalidate];
		[playbackTimer release];
	}
	playbackTimer = [[NSTimer scheduledTimerWithTimeInterval:0.2
													  target:self
													selector:@selector(playerTimerUpdate:)
													userInfo:nil
													 repeats:YES] retain];
}

-(void) setUpAVPlayerForURL: (NSURL*) url {
	[player release];
	player = [[AVPlayer alloc] initWithURL: url];
	if (player) {
		playPauseButton.selected = NO;
		playPauseButton.hidden = NO;
		fileNameLabel.hidden = NO;
		playbackTimeLabel.text = @"0:00";
		playbackTimeLabel.hidden = NO;
		playbackSlider.hidden = NO;
		userIsScrubbing = NO;
		// [self createPlaybackTimer];
		// timer needs to be set up on main thread (in default run loop mode), which is
		// not what calls back from export completion
		[self performSelectorOnMainThread:@selector (createPlaybackTimer)
							   withObject:nil
							waitUntilDone:YES];
	}
}

-(IBAction) handlePlayPauseTapped {
	NSLog (@"handlePlayPauseTapped");
	if (playPauseButton.selected) {
		[player pause];
		playPauseButton.selected = NO;
	} else {
		[player play];
		playPauseButton.selected = YES;
	}
}

-(IBAction) handleSliderValueChanged {
	CMTime seekTime = player.currentItem.asset.duration;
	seekTime.value = seekTime.value * playbackSlider.value;
	seekTime = CMTimeConvertScale (seekTime, player.currentTime.timescale,
								   kCMTimeRoundingMethod_RoundHalfAwayFromZero);
	[player seekToTime:seekTime];
}
-(IBAction) handleSliderTouchDown {
	userIsScrubbing = YES;
}
-(IBAction) handleSliderTouchUp {
	userIsScrubbing = NO;
}

-(void) playerTimerUpdate: (NSTimer*) timer {
	// playback time label
	CMTime currentTime = player.currentTime;
	UInt64 currentTimeSec = currentTime.value / currentTime.timescale;
	UInt32 minutes = currentTimeSec / 60;
	UInt32 seconds = currentTimeSec % 60;
	playbackTimeLabel.text = [NSString stringWithFormat: @"%02d:%02d", minutes, seconds];
	// playback slider
	if (player && !userIsScrubbing) {
		CMTime endTime = CMTimeConvertScale (player.currentItem.asset.duration,
											 currentTime.timescale,
											 kCMTimeRoundingMethod_RoundHalfAwayFromZero);
//		NSLog (@"currentTime.value = %lld, endTime.value = %lld",
//			   currentTime.value, endTime.value);
		if (endTime.value != 0) {
			// float slideTime = currentTime.value / endTime.value; // assuming scales are the same
			double slideTime = (double) currentTime.value / (double) endTime.value;
//			NSLog (@"played %f", slideTime);
			playbackSlider.value = slideTime;
		}
	}
}


#pragma mark other event handlers
-(IBAction) handleChooseSongTapped {
	// show picker
	MPMediaPickerController *pickerController =	[[MPMediaPickerController alloc]
												 initWithMediaTypes: MPMediaTypeMusic];
	pickerController.prompt = @"Choose song to export";
	pickerController.allowsPickingMultipleItems = NO;
	pickerController.delegate = self;
	[self presentModalViewController:pickerController animated:YES];
	[pickerController release];
}

/*
 2010-07-16 16:52:43.961 MediaLibraryExportThrowaway1[690:307] compatible presets for songAsset: (
 AVAssetExportPresetLowQuality,
 AVAssetExportPresetHighestQuality,
 AVAssetExportPreset640x480,
 AVAssetExportPresetMediumQuality,
 AVAssetExportPresetAppleM4A
 )
 */ 


/* With AVAssetExportPresetAppleM4A:
 2010-07-16 14:27:17.248 MediaLibraryExportThrowaway1[1066:307] created exporter. supportedFileTypes: (
 "com.apple.m4a-audio"
 )
 */

/* With AVAssetExportPresetPassthrough [doesn't matter since Passthrough isn't a compatible preset]
 2010-07-16 14:28:21.835 MediaLibraryExportThrowaway1[1081:307] created exporter. supportedFileTypes: (
 "com.apple.quicktime-movie",
 "com.apple.m4a-audio",
 "public.mpeg-4",
 "com.apple.m4v-video",
 "public.3gpp",
 "org.3gpp.adaptive-multi-rate-audio",
 "com.microsoft.waveform-audio",
 "public.aiff-audio",
 "public.aifc-audio"
 */	 

/* MP3 With AVAssetExportPresetAppleM4A:
 2010-07-16 15:04:15.746 MediaLibraryExportThrowaway1[1221:307] created exporter. supportedFileTypes: (
 "com.apple.m4a-audio"
 )
 */


/* MP3 With AVAssetExportPresetPassthrough [doesn't matter since Passthrough isn't a compatible preset]:
 2010-07-16 15:00:37.141 MediaLibraryExportThrowaway1[1187:307] created exporter. supportedFileTypes: (
 "com.apple.quicktime-movie",
 "com.apple.m4a-audio",
 "public.mpeg-4",
 "com.apple.m4v-video",
 "public.3gpp",
 "org.3gpp.adaptive-multi-rate-audio",
 "com.microsoft.waveform-audio",
 "public.aiff-audio",
 "public.aifc-audio"
 )
 */



-(IBAction) handleExportTapped {
	// get the special URL
	if (! song) {
		return;
	}
	NSURL *assetURL = [song valueForProperty:MPMediaItemPropertyAssetURL];
	AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL:assetURL options:nil];

	NSLog (@"Core Audio %@ directly open library URL %@",
		   coreAudioCanOpenURL (assetURL) ? @"can" : @"cannot",
		   assetURL);
	
	NSLog (@"compatible presets for songAsset: %@",
		   [AVAssetExportSession exportPresetsCompatibleWithAsset:songAsset]);
	
	
	/* approach 1: export just the song itself
	 */	
	AVAssetExportSession *exporter = [[AVAssetExportSession alloc]
									  initWithAsset: songAsset
									  presetName: AVAssetExportPresetAppleM4A];
	NSLog (@"created exporter. supportedFileTypes: %@", exporter.supportedFileTypes);
	exporter.outputFileType = @"com.apple.m4a-audio";
	NSString *exportFile = [myDocumentsDirectory() stringByAppendingPathComponent: @"exported.m4a"];
	// end of approach 1
	
	/* approach 1.5: export just the song itself in a quicktime container
	AVAssetExportSession *exporter = [[AVAssetExportSession alloc]
									  initWithAsset: songAsset
									  presetName: AVAssetExportPresetMediumQuality];
	NSLog (@"created exporter. supportedFileTypes: %@", exporter.supportedFileTypes);
	
	// exporter.outputFileType = @"public.mpeg-4"; // nope - uncaught exception 'NSInvalidArgumentException', reason: 'Invalid output file type'
	exporter.outputFileType = @"com.apple.quicktime-movie";
	NSString *exportFile = [myDocumentsDirectory() stringByAppendingPathComponent: @"exported.mov"];
	 // end of approach 1.5
	*/
	
	
	/* approach 2: create a movie with the song as a track, export that
	AVMutableComposition *composition = [AVMutableComposition composition];
	AVMutableCompositionTrack *compositionTrack = [composition addMutableTrackWithMediaType:AVMediaTypeAudio
													preferredTrackID:kCMPersistentTrackID_Invalid];
	AVAssetTrack *songTrack = [songAsset compatibleTrackForCompositionTrack:compositionTrack];
	NSError *insertError = nil;
	[compositionTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, songAsset.duration) 
							  ofTrack:songTrack
							   atTime:kCMTimeZero
								error:&insertError];
	if (insertError) {
		NSLog (@"Error inserting into compositionTrack: %@", insertError);
		return;
	}
	NSLog (@"Created composition");
	AVAssetExportSession *exporter = [[AVAssetExportSession alloc]
									  initWithAsset: composition
									  presetName: AVAssetExportPresetMediumQuality];
	NSLog (@"output types: %@", [exporter supportedFileTypes]);
	exporter.outputFileType = @"com.apple.quicktime-movie";
	NSString *exportFile = [myDocumentsDirectory() stringByAppendingPathComponent: @"exported.mov"];
	 // end of approach 2
	 */

	// set up export (hang on to exportURL so convert to PCM can find it)
	myDeleteFile(exportFile);
	[exportURL release];
	exportURL = [[NSURL fileURLWithPath:exportFile] retain];
	exporter.outputURL = exportURL;	
	
	// do the export
	[exporter exportAsynchronouslyWithCompletionHandler:^{
		int exportStatus = exporter.status;
		switch (exportStatus) {
			case AVAssetExportSessionStatusFailed: {
				// log error to text view
				NSError *exportError = exporter.error;
				NSLog (@"AVAssetExportSessionStatusFailed: %@", exportError);
				errorView.text = exportError ? [exportError description] : @"Unknown failure";
				errorView.hidden = NO;
				break;
			}
			case AVAssetExportSessionStatusCompleted: {
				NSLog (@"AVAssetExportSessionStatusCompleted");
				fileNameLabel.text = [exporter.outputURL lastPathComponent];
				// set up AVPlayer
				[self setUpAVPlayerForURL: exporter.outputURL];
				[self enablePCMConversionIfCoreAudioCanOpenURL: exporter.outputURL];
				break;
			}
			case AVAssetExportSessionStatusUnknown: { NSLog (@"AVAssetExportSessionStatusUnknown"); break;}
			case AVAssetExportSessionStatusExporting: { NSLog (@"AVAssetExportSessionStatusExporting"); break;}
			case AVAssetExportSessionStatusCancelled: { NSLog (@"AVAssetExportSessionStatusCancelled"); break;}
			case AVAssetExportSessionStatusWaiting: { NSLog (@"AVAssetExportSessionStatusWaiting"); break;}
			default: { NSLog (@"didn't get export status"); break;}
		}
	}];
	
	// start up the export progress bar
	exportProgressView.hidden = NO;
	exportProgressView.progress = 0.0;
	NSTimer *progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
															  target:self
															selector:@selector (updateExportProgress:)
															userInfo:exporter
															 repeats:YES];
}

-(void) updateExportProgress: (NSTimer*) timer {
	AVAssetExportSession *exporter = [timer userInfo];
	exportProgressView.progress = exporter.progress;
	// can we end?
	int exportStatus = exporter.status;
	// NSLog (@"updateProgress. status = %d, progress = %f", exportStatus, exporter.progress);
	if ((exportStatus == AVAssetExportSessionStatusCompleted) ||
		(exportStatus == AVAssetExportSessionStatusFailed) ||
		(exportStatus == AVAssetExportSessionStatusCancelled)) {
		NSLog (@"invaldating timer");
		[timer invalidate];
	}
}


#pragma mark MPMediaPickerControllerDelegate
- (void)mediaPicker: (MPMediaPickerController *)mediaPicker
  didPickMediaItems:(MPMediaItemCollection *)mediaItemCollection {
	[self dismissModalViewControllerAnimated:YES];
	if ([mediaItemCollection count] < 1) {
		return;
	}
	[song release];
	song = [[[mediaItemCollection items] objectAtIndex:0] retain];
	songLabel.hidden = NO;
	artistLabel.hidden = NO;
	coverArtView.hidden = NO;
	songLabel.text = [song valueForProperty:MPMediaItemPropertyTitle];
	artistLabel.text = [song valueForProperty:MPMediaItemPropertyArtist];
	coverArtView.image = [[song valueForProperty:MPMediaItemPropertyArtwork]
						  imageWithSize: coverArtView.bounds.size];
	exportButton.hidden = NO;
	exportButton.enabled = YES;
	// hide all the post-export stuff
	[player pause];
	exportProgressView.hidden = YES;
	errorView.hidden = YES;
	fileNameLabel.hidden = YES;
	playbackSlider.hidden = YES;
	playPauseButton.hidden = YES;
	playPauseButton.selected = NO;
	playbackTimeLabel.text = @"0:00";
	playbackTimeLabel.hidden = YES;
	userIsScrubbing = NO;
	coreAudioIcon.hidden = YES;
	coreAudioCompatibilityLabel.hidden = YES;
	convertToPCMButton.hidden = YES;
	pcmFileSizeLabel.hidden = YES;
	if (playbackTimer) {
		[playbackTimer invalidate];
		[playbackTimer release];
		playbackTimer = nil;
	}
}

- (void)mediaPickerDidCancel:(MPMediaPickerController *)mediaPicker {
	[self dismissModalViewControllerAnimated:YES];
}


#pragma mark core audio convert to pcm
-(IBAction) handleConvertToPCMTapped {
	NSLog (@"handleConvertToPCMTapped");
	
	// open an ExtAudioFile
	NSLog (@"opening %@", exportURL);
	ExtAudioFileRef inputFile;
	CheckResult (ExtAudioFileOpenURL((CFURLRef)exportURL, &inputFile),
				 "ExtAudioFileOpenURL failed");
	
	// prepare to convert to a plain ol' PCM format
	AudioStreamBasicDescription myPCMFormat;
	myPCMFormat.mSampleRate = 44100; // todo: or use source rate?
	myPCMFormat.mFormatID = kAudioFormatLinearPCM ;
	myPCMFormat.mFormatFlags =  kAudioFormatFlagsCanonical;	
	myPCMFormat.mChannelsPerFrame = 2;
	myPCMFormat.mFramesPerPacket = 1;
	myPCMFormat.mBitsPerChannel = 16;
	myPCMFormat.mBytesPerPacket = 4;
	myPCMFormat.mBytesPerFrame = 4;
	
	CheckResult (ExtAudioFileSetProperty(inputFile, kExtAudioFileProperty_ClientDataFormat,
									  sizeof (myPCMFormat), &myPCMFormat),
			  "ExtAudioFileSetProperty failed");

	// allocate a big buffer. size can be arbitrary for ExtAudioFile.
	// you have 64 KB to spare, right?
	UInt32 outputBufferSize = 0x10000;
	void* ioBuf = malloc (outputBufferSize);
	UInt32 sizePerPacket = myPCMFormat.mBytesPerPacket;	
	UInt32 packetsPerBuffer = outputBufferSize / sizePerPacket;
	
	// set up output file
	NSString *outputPath = [myDocumentsDirectory() stringByAppendingPathComponent:@"export-pcm.caf"];
	NSURL *outputURL = [NSURL fileURLWithPath:outputPath];
	NSLog (@"creating output file %@", outputURL);
	AudioFileID outputFile;
	CheckResult(AudioFileCreateWithURL((CFURLRef)outputURL,
									   kAudioFileCAFType,
									   &myPCMFormat, 
									   kAudioFileFlags_EraseFile, 
									   &outputFile),
			  "AudioFileCreateWithURL failed");
	
	// start convertin'
	UInt32 outputFilePacketPosition = 0; //in bytes
	
	while (true) {
		// wrap the destination buffer in an AudioBufferList
		AudioBufferList convertedData;
		convertedData.mNumberBuffers = 1;
		convertedData.mBuffers[0].mNumberChannels = myPCMFormat.mChannelsPerFrame;
		convertedData.mBuffers[0].mDataByteSize = outputBufferSize;
		convertedData.mBuffers[0].mData = ioBuf;

		UInt32 frameCount = packetsPerBuffer;

		// read from the extaudiofile
		CheckResult (ExtAudioFileRead(inputFile,
									  &frameCount,
									  &convertedData),
					 "Couldn't read from input file");
		
		if (frameCount == 0) {
			printf ("done reading from file");
			break;
		}
		
		// write the converted data to the output file
		CheckResult (AudioFileWritePackets(outputFile,
										   false,
										   frameCount,
										   NULL,
										   outputFilePacketPosition / myPCMFormat.mBytesPerPacket, 
										   &frameCount,
										   convertedData.mBuffers[0].mData),
					 "Couldn't write packets to file");
		
		NSLog (@"Converted %ld bytes", outputFilePacketPosition);

		// advance the output file write location
		outputFilePacketPosition += (frameCount * myPCMFormat.mBytesPerPacket);
	}
	
	// clean up
	ExtAudioFileDispose(inputFile);
	AudioFileClose(outputFile);

	// show size in label
	NSLog (@"checking file at %@", outputPath);
	if ([[NSFileManager defaultManager] fileExistsAtPath:outputPath]) {
		NSError *fileManagerError = nil;
		unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:outputPath
																					   error:&fileManagerError]
									   fileSize];
		if (fileManagerError) {
			pcmFileSizeLabel.text = fileManagerError.localizedFailureReason;
		} else {
			pcmFileSizeLabel.text = [NSString stringWithFormat: @"%lld bytes", fileSize];
		}
		pcmFileSizeLabel.hidden = NO;
	} else {
		NSLog (@"no file at %@", outputPath);
	}
	
}


@end
