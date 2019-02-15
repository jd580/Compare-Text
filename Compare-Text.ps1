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

    # Compare objects with line numbers and sort by line number
    $numberedTextDifference = Compare-Object -ReferenceObject $numberedReference -DifferenceObject $numberedDifference -IncludeEqual -Property Text,LineNum | 
        sort-object -Property LineNum

    $newConfigurationParams = @{
        TextDifference             = $textDifference
        NumberedReference          = $numberedReference
        NumberedDifference         = $numberedDifference
        CombinedNumberedDifference = $numberedTextDifference
    }

    Write-NewConfiguration @newConfigurationParams
    
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

function Write-NewConfiguration
{
    param
    (
        [Parameter(Mandatory = $true)]
        $TextDifference,

        [Parameter(Mandatory = $true)]
        $NumberedReference,

        [Parameter(Mandatory = $true)]
        $NumberedDifference,

        [Parameter(Mandatory = $true)]
        $CombinedNumberedDifference
    )

    # Array list for equal, ReferenceDifference and DifferenceDifference
    $equalArray = [System.Collections.ArrayList]::new()
    $referenceArray = [System.Collections.ArrayList]::new()
    $differenceArray = [System.Collections.ArrayList]::new()
    # separate $TextDifference into appropriate arrays
    foreach ($diff in $textDifference)
    {
        switch ($diff.SideIndicator)
        {
            '=='
            {
                $null = $equalArray.Add($diff)
                break
            }
            '<='
            {
                $null = $referenceArray.Add($diff)
                break
            }
            '=>'
            {
                $null = $differenceArray.Add($diff)
                break
            }
        }
    }

    
    $lineCount = 1
    foreach ($line in $CombinedNumberedDifference)
    {
        switch ($line.Text) 
        {
            {$PSItem -eq $equalArray[0].InputObject} 
            {  
                $strLine = $line.Text
                $strLine = "$strLine".replace("`t"," ")
                "[{0}]`t{1}" -f $line.LineNum, $strLine | Write-Output

                $null = $equalArray.Remove($equalArray[0])
                break
            }
            {$PSItem -eq $referenceArray[0].InputObject}
            {
                "Reference[{0}]`t{1}" -f $lineCount, $line.Text | Write-Host -BackgroundColor Green -ForegroundColor Black

                $null = $referenceArray.Remove($referenceArray[0])
                break
            }
            {$PSItem -eq $differenceArray[0].InputObject}
            {
                $lineCount = $lineCount - 1
                "Difference[{0}]`t{1}" -f $lineCount, $line.Text | Write-Host -BackgroundColor Red -ForegroundColor Black
                
                $null = $differenceArray.Remove($differenceArray[0])
                break
            }
        }

        $lineCount++
    }

    #foreach ($line in $NumberedReference)
}

Compare-Configuration -ReferenceConfigPath 'C:\Users\phili\Desktop\Compare function\Config1.txt' -DifferenceConfigPath 'C:\Users\phili\Desktop\Compare function\Config2.txt'
