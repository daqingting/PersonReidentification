%This program is used to extract features using the method proposed in paper
%'Local Fisher Discriminant Analysis for Pedestrian Re-identification'

%get all image names of camera_a
function featureExtraction()

setpaths
folderA = dir('VIPeR/cam_a');
imageRGB = [];
imageAHSV = {};
imageAYUV = {};

%load('aleMasks_VIPeR.mat');

%read images
fprintf('Read Images from Camera A************************:\n');
for i = 3:size(folderA,1)
	imageRGB = imread(strcat('VIPeR/cam_a/',folderA(i).name));
%     temp = msk{i-2};
%     mask = repmat(temp,[1,1,3]);
%     imageRGB = bsxfun(@times,uint8(mask),imageRGB);
	[imageAHSV{i-2}, imageAYUV{i-2}] = imageConvert(imageRGB);
end

%get all images names of cam_b
fprintf('Read Images from Camera B************************:\n');
folderB = dir('VIPeR/cam_b');
imageBHSV = {};
imageBYUV = {};

%read images
for i = 3:size(folderB,1)
	imageRGB = imread(strcat('VIPeR/cam_b/',folderB(i).name));
% 	temp = msk{i-2 + 632};
%     mask = repmat(temp,[1,1,3]);
%     imageRGB = bsxfun(@times,uint8(mask),imageRGB);
    [imageBHSV{i-2}, imageBYUV{i-2}] = imageConvert(imageRGB);
end

save('imageData','imageAHSV','imageAYUV','imageBHSV','imageBYUV');

%load('imageData');

%extract features for each image
featureAHSV = {};
featureAYUV = {};
featureBHSV = {};
featureBYUV = {};


for i = 1 : size(imageAHSV,2)
    fprintf('Extract features    %d     +++++++++\n',i);
	[featureAHSV{i},featureAYUV{i}] = extractFeature(imageAHSV{i}, imageAYUV{i});
end

for i = 1 : size(imageBHSV,2)
    fprintf('Extract features    %d     ---------\n',i);
	[featureBHSV{i},featureBYUV{i}] = extractFeature(imageBHSV{i}, imageBYUV{i});
end

save('feature.mat','featureAHSV','featureAYUV','featureBHSV','featureBYUV');





function [imageHSV,imageYUV]=imageConvert(imageRGB)

	fprintf('Convert images into HSV and YUV:=====================\n');
	imageHSV = rgb2hsv(imageRGB);

	% rgb2yuv = [.299  .587  .144; 
 %    	   -.147 -.289  .436; 
 %     	   .615 -.515 -.1];

 %    imageYUV = zeros(size(imageRGB));

 %    for i = 1 : size(imageYUV,1)
 %    	for j = 1 : size(imageYUV,2)
 %    		imageYUV(i,j,:) = rgb2yuv * vec(imageRGB(i,j,:));
 %    	end
 %    end
    imageYUV = rgb2ycbcr(imageRGB);

end



function [hsvFinal,yuvFinal] = extractFeature(imageHSV,imageYUV)
	%get sample tiles from the image, each sample is 16 * 8
	%we get a sample every 4 pixels
	
	featureHSV = {};
	featureYUV = {};
	num = 1;
	
	%for each sample, we calculate their corresponding vectors
	%the method for HSV and YUV is exactly the same
	for y = 1 : 4 : (128 - 3)
		for x = 1 : 4 : (48 - 7)
            %fprintf('x:%d, y:%d\n',x,y);
			[featureHSV{num}, featureYUV{num}] = getFeature(imageHSV(y:y+3, x:x+7,:),imageYUV(y:y+3, x:x+7,:));
			num = num+1;
        end
    end

    %combine the features of all samples together
    %for HSV
    hsvFinal = []; 
    for i = 1: num-1
    	hsvFinal = [hsvFinal;featureHSV{i}];
    end

    %for YUV
    yuvFinal = [];
    for i = 1:num-1
    	yuvFinal = [yuvFinal;featureYUV{i}];
    end

    %following do PCA to the HSV feature and YUV feature

end

function [featureHSV,featureYUV] = getFeature(sample1,sample2)
	%the feature is composed of two parts, the first part is a 8-bin
	%histogram of the three channels(HSV or YUV). The second part is the 
	%color moment of the three channels.

	%get historgram for H,S,V or Y,U,V

	%value for Hue in HSV 
	hPart = eightBinHist(vec(sample1(:,:,1)), 0, 1); 
	%value for Saturation in HSV or U in YUV
	sPart = eightBinHist(vec(sample1(:,:,2)),0,1);
	%value for V in HSV and YUV
        vPart = eightBinHist(vec(sample1(:,:,3)),0,1);

	%get three color moments for H,S,V or Y,U,V
	momentH = colorMoments(vec(sample1(:,:,1)));
	momentS = colorMoments(vec(sample1(:,:,2)));
	momentV = colorMoments(vec(sample1(:,:,3)));
     
	featureHSV = [hPart;sPart;vPart;momentH;momentS;momentV];

    
    %calculate feature for YUV
	yPart = eightBinHist(vec(sample2(:,:,1)), 16, 235); 
	%value for Saturation in HSV or U in YUV
	uPart = eightBinHist(vec(sample2(:,:,2)),16,240);
	%value for V in HSV and YUV
    vPart = eightBinHist(vec(sample2(:,:,3)),16,240);

	%get three color moments for H,S,V or Y,U,V
	momentY = colorMoments(double(vec(sample2(:,:,1))));
	momentU = colorMoments(double(vec(sample2(:,:,2))));
	momentV = colorMoments(double(vec(sample2(:,:,3))));
     
	featureYUV = [yPart;uPart;vPart;momentY;momentU;momentV];
    
    
end


  
%this function is used to calculate the histograms the sample.
%the histogram is a standard 8-bin histogram.
function eightBin = eightBinHist(value,minValue,maxValue)
	%divide 0-1 into 8 parts, that is 0 - 0.125, 0,125--0.25,...
	%use histc() to count the frequency
	bins = linspace(minValue,maxValue,9);   
    eightBin = histc(value,bins);   
    %eightBin(8,1) = eightBin(8,1) + eightBin(9,1);  %the last element is added to 
    %normalize the result
    if(size(value,1) == 0)
        fprintf('--------------------------------\n\n');
    end
    
    
    eightBin = eightBin(1:8); 
end

%this function is used to calculate the three color moments 
function moment = colorMoments(value)
	%first moment, that is 'Mean', the average color value in the image
%     if(size(value,1) == 0)
%         fprintf('++++++++++++++++++++++++++++++\n\n');
%     end
	moment1 = sum(value)/size(value,1);

	%second moment, that is 'standard deviation'
	moment2 = std(value,1);

	%third moment, that is 'skewness'
	moment3 = skewness(value);

	moment = [moment1;moment2;moment3];

end



end











