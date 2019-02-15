function Compare-Configuration
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $ReferenceConfigPath,

        [Parameter(Mandatory = $true)]
        [string]
        $DifferenceConfigPath
    )

    $referenceConfig = Get-Content -Path $ReferenceConfigPath
    $differenceConfig = Get-Content -Path $DifferenceConfigPath

    # Create line numbers
    $numberedReference = Add-LineNumber -Text $referenceConfig
    $numberedDifference = Add-LineNumber -Text $differenceConfig

    # Compare initial objects
    $textDifference = Compare-Object -ReferenceObject $referenceConfig -DifferenceObject $differenceConfig -IncludeEqual

    # Initialize arrays
    $objNotInFile1 = [System.Collections.ArrayList]::new()
    $objNotInFile2 = [System.Collections.ArrayList]::new()

    # Add differing objects to new arrays
    foreach ($diff in $textDifference)
    {
        if ($diff.SideIndicator -eq "=>") 
        {
            $null = $objNotInFile1.Add($diff)
        }
        elseif ($diff.SideIndicator -eq "<=") 
        {
            $null = $objNotInFile2.Add($diff)
        }
    } 

    # Compare objects with line numbers and sort by line number
    $objDiff2 = Compare-Object -ReferenceObject $numberedReference -DifferenceObject $numberedDifference -IncludeEqual -Property Text,LineNum | sort-object -Property LineNum
    
    $test = Collect-Whatever -DifferenceObject $textDifference -NumberedDifferenceObject $objDiff2
    # Initialize some variables
    $lngCounterNotInFile1 = 0
    $lngCounterNotInFile2 = 0
    #$lngMaxCharacters = 60

     foreach ($objDifference in $objDiff2) 
     {
        if ($objDifference.SideIndicator -eq '=>') 
        {
            if ($objNotInFile1[$lngCounterNotInFile1].InputObject -eq $objDifference.Text)
            {
                "Difference[{1}]`t{2}" -f $objDifference.SideIndicator, $objDifference.LineNum, $objDifference.Text | Write-Host -BackgroundColor yellow -ForegroundColor black
                if ($lngCounterNotInFile1 -lt $objNotInFile1.count) 
                {
                    $lngCounterNotInFile1 ++
                }
            }
        }
        elseif ($objDifference.SideIndicator -eq '<=')
        {
            if ($objNotInFile2[$lngCounterNotInFile2].InputObject -eq $objDifference.Text)
            {
                "Reference[{1}]`t{2}" -f $objDifference.SideIndicator, $objDifference.LineNum, $objDifference.Text | Write-Host -BackgroundColor yellow -ForegroundColor black
                if ($lngCounterNotInFile2 -lt $objNotInFile2.count) 
                {
                    $lngCounterNotInFile2 ++
                }
            }
        }
        else 
        {
            $strLine = $objDifference.Text
            $strLine = "$strLine".replace("`t"," ")
            # if ("$strLine".length -gt $lngMaxCharacters){$strLine = "$strLine".substring(0,$lngMaxCharacters-3)+"…"}
            "[{0}]`t{1}" -f $objDifference.LineNum, $strLine | Write-Output 
        }
    } 
}

function Add-LineNumber
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string[]]
        $Text
    )

    $lineNumber = 1
    $return = [System.Collections.ArrayList]::new()
    foreach ($line in $Text)
    {
        $object = New-Object -TypeName psobject -Property @{
            LineNum = $lineNumber
            Text    = $line.Trim()
        }

        $null = $return.Add($object)
        $lineNumber++
    }

    return $return
}

function Collect-Whatever
{
    param
    (
        [Parameter()]
        $DifferenceObject,

        [Parameter()]
        $NumberedDifferenceObject
    )

    $correct = $DifferenceObject | Where-Object -FilterScript {$_.SideIndicator -eq '=='}

    $uniqueLineNum = $NumberedDifferenceObject.LineNum | Select-Object -Unique
    $sortedLineNum = $uniqueLineNum | Sort-Object 
    $returnArray = [System.Collections.ArrayList]::new()
    # Collecting the Numbered Difference Objects that only have one line number
    # This translates to the defference objects really having a '==' side indicator in the normal difference 
    foreach ($num in $sortedLineNum)
    {
        $lineobject = $NumberedDifferenceObject | Where-Object -FilterScript {$_.LineNum -eq $num}

        if ($lineobject.Text.count -eq 1)
        {
            $null = $returnArray.Add($lineobject)
        }
    }

    return $returnArray
}
