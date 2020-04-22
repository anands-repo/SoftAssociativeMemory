#!/usr/bin/perl

#This SDM adds addresses as and when programmed
package trainedSDM;

use Math::BigFloat;

#Program an element
#If the element doesn't exist, create the element and cluster addresses around it uniformly randomly if clustering should be checked.
#If clustering need not be checked, just add the addresses
#If density is zero, use just one location to store the element
sub program {
    my $sdm              = shift;
    my $address          = shift;
    my $multiplicity     = shift;

    my $density          = $sdm->{'density'};
    my $memory           = $sdm->{'memory'};
    my $bitWidth         = $sdm->{'bitWidth'};
    my $trainingDistance = $sdm->{'distance'};
    my $threshold        = $sdm->{'threshold'};
    my $saturateAt       = $sdm->{'saturateAt'};

    my @addressArray     = split //, $address;

    if ($density > 0) {
        foreach (1 .. $trainingDistance) { #This is also not good enough ... we actually have to cluster the reads on the diametrically opposite side of the existing address
            my $numDifferences    = $_;
            my $numAddressVectors = int ($density / (2 ** $bitWidth) * (Math::BigFloat->new("$bitWidth")->bnok($numDifferences)));
            if ($checkClustering =~ /true/) {
                foreach $currentAddress (keys %$memory) {
                    if (&hammingDistance($currentAddress, $address) == $numDifferences) {
                        $numAddressVectors--;
                    }
                }
            }
            foreach (1 .. $numAddressVectors) {
                my $newLocation = map {0} (0 .. $bitWidth - 1); #Passed by reference, hence always create fresh
                my $newAddress  = &createAddressDifferences($address, $numDifferences);
                $memory->{$newAddress} = $newLocation; 
            }
        }
        #Traverse through the memory again and store everywhere that is within the threshold hamming distance
        foreach (keys %$memory) {
            my $currentLocation = $_;
            if (&hammingDistance($address, $currentLocation) > $threshold) {
                my $location = $memory->{$currentLocation};
                my $newLocation = map { $addressArray->[$_] =~ /1/ ? $location->[$_] + $multiplicity : $location->[$_] - $multiplicity } (0 .. $bitWidth - 1);
                $memory->{$currentLocation} = $newLocation;
            }
        }
    } else { #Store at all addresses within the threshold hamming distance. If none is available, store in a new location having the same address
        my $stored = 0;
        foreach $currentAddress (keys %$memory) {
            if (&hammingDistance($currentAddress, $address) <= $threshold) {
                my $location               = $memory->{$currentAddress};
                my @locationArray          = map {$addressArray[$_] =~ /1/ ? $location->[$_] + $multiplicity : $location->[$_] - $multiplicity} (0 .. $bitWidth - 1);
                $memory->{$currentAddress} = \@locationArray;
                $stored                    = 1;
            }
        }
        if ($stored == 0) {
            my $locationArray = map { $addressArray[$_] =~ /1/ ? $multiplicity : -$multiplicity } (0 .. $bitWidth - 1);
            $memory->{$address} = $locationArray;
        }
        #Check for saturation and reset the corresponding address and data bits
        my $locationArray = $memory->{$address};
        my $allSaturated  = 1;
        my $newAddress    = join '', map { $locationArray->[$_] > $saturateAt ? '1' : $locationArray->[$_] < -$saturateAt ? '0' : $addressArray->[$_] } (0 .. $bitWidth - 1);
        my $newLocation   = map { $locationArray->[$_] > $saturateAt ? '1' : $locationArray->[$_] < -$saturateAt ? '0' : $locationArray->[$_] } (0 .. $bitWidth - 1);
        delete $memory->{$address};
        $memory->{$newAddress} = $newLocation;
    }
    $sdm->{'memory'} = $memory;
}

#Read all locations within hamming distance if density is more than zero, else read from one location within hamming distance
sub read {
    my $sdm         = shift;
    my $address     = shift;

    my $threshold   = $sdm->{'threshold'};
    my $density     = $sdm->{'density'};
    my $hysteresis  = $sdm->{'hysteresis'};
    my $memory      = $sdm->{'memory'};
    my $bitWidth    = $sdm->{'bitWidth'};

    my $pooledLocation = map {0} (0 ..  $bitWidth - 1);

    foreach $currentAddress (%$memory) {
        if (&hammingDistance($currentAddress, $address) < $threshold) {
            if ($density == 0) {
                $pooledLocation = $memory->{$currentAddress};
                last;
            } else {
                foreach $index (0 .. $bitWidth - 1) {
                    $pooledLocation->[$index] += $memory->{$currentAddress}[$index];
                }
            }
        }
    }

    my @returnDataArray = map {$_ > $hysteresis ? '1' : $_ < -$hysteresis ? : '0' : 'x'} @$pooledLocation;

    return join '', @returnDataArray;
}

#New function
sub new {
    my $self             = shift;
    my $bitWidth         = shift;
    my $trainingDistance = shift;
    my $threshold        = shift;
    my $hysteresis       = shift;
    my $density          = shift; #If density is zero, at the training distance, if there is one location, no more locations are created
                                  #Density is expressed in total number of locations
    my $saturateAt       = shift;
 
    #Initialize memory data-structure with a random address
    #Grow the memory as needed later on
    my $memory           = {&createRandomBitString($bitWidth) => (map {0} (0 .. $bitWidth  1))};

    my $sdm              = {};

    $sdm->{'bitWidth'}         = $bitWidth;
    $sdm->{'threshold'}        = $threshold;
    $sdm->{'hysteresis'}       = $hysteresis;
    $sdm->{'distance'}         = $trainingDistance;
    $sdm->{'memory'}           = $memory;
    $sdm->{'density'}          = $density;
    $sdm->{'saturateAt'}       = $saturateAt;
    $sdm->{'checkClustering'}  = 'false';

    bless $sdm, $self;

    return $sdm;
};

sub createRandomBitString {
    my $bitWidth = shift;
    
    return join '', map {int rand 2} (0 .. $bitWidth - 1);
}

sub hammingDistance {
    my $string0 = shift;
    my $string1 = shift;

    my $index;

    my @string0Chars = split //, $string0;
    my @string1Chars = split //, $string1;

    my $hammingDistance = 0;

    foreach $index (0 .. $#string0Chars) {
        $hammingDistance ++ if (!($string0Chars[$index] =~ /$string1Chars[$index]/));
    }

    return $hammingDistance;
}

sub createAddressDifferences {
    my $address        = shift;
    my $numDifferences = shift;

    my $invert = {};
    $invert->{'0'} = '1';
    $invert->{'1'} = '0';

    my @addressArray = split //, $address;
  
    foreach (1 .. $numDifferences) {
        my $errorPos = int rand ($#addressArray + 1);
        $addressArray[$errorPos] = $invert->{$addressArray[$errorPos]};
    }

    return join '', @addressArray;
}

1;
