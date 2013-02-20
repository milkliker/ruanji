//
//  ViewController.m
//  ruanji
//
//  Created by 赵君 on 13-2-19.
//  Copyright (c) 2013年 赵君. All rights reserved.
//

#import "ViewController.h"
#import "OouraFFT.h"

@interface ViewController ()

@end

@implementation ViewController
{
@private
    NSURL *tmp_record_file;
    AVAudioRecorder *recorder;
    BOOL IS_ON_RECORD;
}

- (void)updateMeters:(NSTimer *)sender
{    
    [recorder updateMeters];
	double power = pow(10, (0.05 * [recorder averagePowerForChannel:0]));

    self.frequency.text = [[NSString alloc] initWithFormat:@"%f", power];
    
    if (power > 0.05) {
        IS_ON_RECORD = YES;
    } else if (IS_ON_RECORD) {
        [recorder stop];
        [self calculateFrequency];
        IS_ON_RECORD = NO;
        [recorder record];
    } else {
        [recorder stop];
        [recorder record];
    }
}

- (void)calculateFrequency
{
    
    AVURLAsset *songAsset = [[AVURLAsset alloc] initWithURL:tmp_record_file options:nil];

    AVAssetReader * reader = [[AVAssetReader alloc] initWithAsset:songAsset error:nil];
    
    AVAssetTrack * songTrack = [songAsset.tracks objectAtIndex:0];
    
    NSDictionary* outputSettingsDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                                        
                                        [NSNumber numberWithInt:kAudioFormatLinearPCM],AVFormatIDKey,
                                        [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsNonInterleaved,
                                        
                                        nil];
    
    
    AVAssetReaderTrackOutput* output = [[AVAssetReaderTrackOutput alloc] initWithTrack:songTrack outputSettings:outputSettingsDict];
    
    [reader addOutput:output];
    
    UInt32 sampleRate,channelCount;
    
    NSArray* formatDesc = songTrack.formatDescriptions;
    
    for (unsigned int i = 0; i < [formatDesc count]; ++i) {
        CMAudioFormatDescriptionRef item = (__bridge CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:i];
        const AudioStreamBasicDescription* fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription (item);
        if (fmtDesc) {
            sampleRate = fmtDesc->mSampleRate;
            channelCount = fmtDesc->mChannelsPerFrame;
        }
    }
    
    UInt32 bytesPerSample = 2 * channelCount;
    [reader startReading];

    NSMutableDictionary* music_data = [[NSMutableDictionary alloc] init];
    int max_count_freq = 0;
    int max_count = 0;
    while (reader.status == AVAssetReaderStatusReading){
        
        AVAssetReaderTrackOutput * trackOutput = (AVAssetReaderTrackOutput *)[reader.outputs objectAtIndex:0];
        CMSampleBufferRef sampleBufferRef = [trackOutput copyNextSampleBuffer];
        
        if (sampleBufferRef){
            
            CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);
            
            size_t length = CMBlockBufferGetDataLength(blockBufferRef);
            
            NSMutableData * data = [NSMutableData dataWithLength:length];
            CMBlockBufferCopyDataBytes(blockBufferRef, 0, length, data.mutableBytes);
            
            SInt16 * samples = (SInt16 *) data.mutableBytes;
            
            int sampleCount = length / bytesPerSample;

            OouraFFT *fft = [[OouraFFT alloc] initForSignalsOfLength:sampleCount andNumWindows:10];

            for (int i = 0; i < sampleCount ; i ++) {
                double left = *samples++;
                double right = 0;
                
                if (channelCount == 2) {
                    right = *samples++;
                }
                fft.inputData[i] = left;
            }
            
            [fft calculateWelchPeriodogramWithNewSignalSegment];
            
            int max_freq = 0;
            double max_freq_value = 0;
            
            for (int i = 0; i < fft.numFrequencies; i++) {
                if (fft.spectrumData[i] && fft.spectrumData[i] < 10000000 && fft.spectrumData[i] > 100 && fft.spectrumData[i] > max_freq_value) {
                    max_freq_value = fft.spectrumData[i];
                    max_freq = i;
                }
            }

            NSString *key = [[NSString alloc] initWithFormat:@"%d", max_freq];
            NSNumber *count;
            if ([music_data objectForKey:key]) {
                count = [[NSNumber alloc] initWithInt:[[music_data objectForKey:key] intValue] + 1];
            } else {
                count = [[NSNumber alloc] initWithInt:1];
            }
            [music_data setValue:count forKey:key];
            
            if ([count intValue] > max_count) {
                max_count = [count intValue];
                max_count_freq = max_freq;
            }
            
            CMSampleBufferInvalidate(sampleBufferRef);
            
            CFRelease(sampleBufferRef);
        }
        
        //[progress setProgress:time_point / total_time];
    }
    
    if (reader.status == AVAssetReaderStatusFailed || reader.status == AVAssetReaderStatusUnknown){
        // Something went wrong. return nil
        
       // return nil;
    }

    if (reader.status == AVAssetReaderStatusCompleted){
        NSLog(@"%@", music_data);
        //NSLog(@"freq:%d count:%d", max_count_freq, max_count);
        //NSLog(@"ct:%d", ctr);
      //  return music_data;
    }
    
  //  return nil;

}

- (void)startRecorder
{
    NSString *recordedAudioPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)
                                   objectAtIndex:0];
    recordedAudioPath = [recordedAudioPath stringByAppendingPathComponent:@"recorded.caf"];
    tmp_record_file = [NSURL fileURLWithPath:recordedAudioPath];
    
    recorder = [[AVAudioRecorder alloc] initWithURL:tmp_record_file settings:nil error:nil];
    
    [recorder prepareToRecord];
    
    recorder.meteringEnabled = YES;
    
    [recorder record];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.frequency.text = @"Y";

    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [session setActive:YES error:nil];

    [self startRecorder];
    
	NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateMeters:) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
}

- (void)viewDidUnload
{
    [self removeTmpRecordFile];
    [super viewDidUnload];
}

-(void)removeTmpRecordFile
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    // [fileManager removeItemAtPath:recordedFile.path error:nil];
    [fileManager removeItemAtURL:tmp_record_file error:nil];
    tmp_record_file = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)start:(id)sender {
    [self startRecorder];
}
@end
