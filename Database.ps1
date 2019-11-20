class Node
{
    <#
    NOTE: The rotations were later implemented into the structure later on FOUO workplace. Unable to retrieve.
    Each Node has a value for keeping the binary structure operational (searching), and then a m_data variable for the rest of the data.


    Two methods requires RSAT AD Objects


    MEMBERS:
        [Node]$m_left
            left member.
        [Node]$m_right
            right member.
        [string]$m_value
            this node's string name for comparison.
        [int16]$m_height = 1
            AVL balance.
        [array]$m_data
            node's real data by relation of name. Due to unknown nature, this is type array

    METHODS:
        [void] newSelf ([string]$value, $parent, [array]$data)
            restructures itself. may throw off data..
        [void] newLeft ([string]$value, [array]$data)
            creates new left member.
        [void] newRight ([string]$value, [array]$data)
            creates new right member.

        [string] showSelf ()
            returns name of this node.
        [string] showLeft ()
            returns name of left node.
        [string] showRight ()
            returns name of right node.

        [array] get ([string]$var)
            returns data of searched name.
            returns null if no result.
        [array] get ([Microsoft.ActiveDirectory.Management.ADAccount]$var)
            returns data of searched name - accepts AD computer object.
            returns null if no result.

        [void] add ([string]$var, $data)
            Adds value,data into nodes. Does nothing on match found
        [void] add ([[Microsoft.ActiveDirectory.Management.ADAccount]$var, $data)
            Adds value,data into nodes. Does nothing on match found

    TODO:
        Add support for array gets.
    #>

    [Node]$m_left
    [Node]$m_right

    [string]$m_value
    [int16]$m_height = 1
    
    [array]$m_data


    Node ([string]$value, [array]$data)
    {
        $this.m_value = $value
        $this.m_data = $data
    }
    
    [void] newSelf ([string]$value, [array]$data)
    {
        $this.m_value = $value
        $this.m_data = $data
    }

    [void] newLeft ([string]$value, [array]$data)
    {
        $this.m_left = New-Object -TypeName Node -ArgumentList $value,$data
    }

    [void] newRight ([string]$value, [array]$data)
    {
        $this.m_right = New-Object -TypeName Node -ArgumentList $value,$data
    }

    [string] showSelf ()
    {
        return $this.m_value
    }

    [string] showLeft ()
    {
        if ($this.m_left)
        {
            return $this.m_left.showSelf()
        }
        else
        {
            return $null
        }
    }

    [string] showRight ()
    {
        if ($this.m_right)
        {
            return $this.m_right.showSelf()
        }
        else
        {
            return $null
        }
    }


    #-------# Logic

    [array] get ([string]$var)
    {
        # <
        if ($var -lt $this.m_value)
        {
            if ($this.m_left)
            {
                return $this.m_left.get($var)
            }
            else
            {
                return $null
            }
        }
        # >
        elseif ($var -gt $this.m_value)
        {
            if ($this.m_right)
            {
                return $this.m_right.get($var)
            }
            else
            {
                return $null
            }
        }
        # ==
        else
        {
            return $this.m_data
        }
    }

    [array] get ([Microsoft.ActiveDirectory.Management.ADAccount]$var)
    {
        if ($var.ObjectClass -ne "computer")
        {
            throw "Error: Input not computer class object"
        }


        # <
        if ($var.Name -lt $this.m_value)
        {
            if ($this.m_left)
            {
                return $this.m_left.get($var.Name)
            }
            else
            {
                return $null
            }
        }
        # >
        elseif ($var.Name -gt $this.m_value)
        {
            if ($this.m_right)
            {
                return $this.m_right.get($var.Name)
            }
            else
            {
                return $null
            }
        }
        # ==
        else
        {
            return $this.m_data
        }
    }

    [Node] add ([string]$var, $data)
    {
        # <
        if ($var -lt $this.m_value)
        {
            if ($this.m_left)
            {
                $this.m_left.add($var)
            }
            else
            {
                $this.newLeft($var,$data)
                $this.m_height = 1 + [Node]::max($this.m_left.m_height, $this.m_right.m_height)
            }
        }
        # >
        elseif ($var -gt $this.m_value)
        {
            if ($this.m_right)
            {
                $this.m_right.add($var)
            }
            else
            {
                $this.newRight($var,$data)
                $this.m_height = 1 + [Node]::max($this.m_left.m_height, $this.m_right.m_height)
            }
        }
        # ==
        else
        {
            Write-Verbose "Node already exists $var"
        }
    }

    [Node] add ([Microsoft.ActiveDirectory.Management.ADAccount]$var, $data)
    {
        if ($var.ObjectClass -ne "computer")
        {
            throw "Error: Input not computer class object"
        }

        # <
        if ($var.Name -lt $this.m_value)
        {
            if ($this.m_left)
            {
                $this.m_left.add($var)
                $this.m_height = 1 + [Node]::max($this.m_left.m_height, $this.m_right.m_height)
            }
            else
            {
                $this.newLeft($var,$data)
                $this.m_height = 1 + [Node]::max($this.m_left.m_height, $this.m_right.m_height)
            }
        }
        # >
        elseif ($var.Name -gt $this.m_value)
        {
            if ($this.m_right)
            {
                $this.m_right.add($var)
                $this.m_height = 1 + [Node]::max($this.m_left.m_height, $this.m_right.m_height)
            }
            else
            {
                $this.newRight($var,$data)
                $this.m_height = 1 + [Node]::max($this.m_left.m_height, $this.m_right.m_height)
            }
        }
        # ==
        else
        {
            Write-Verbose ("Node already exists " + $var.Name)
        }
    }

    static [int16] max ([int16]$a, [int16]$b)
    {
        # function to determine the biggest value
        if ($a -gt $b)
        {
            return $a
        }
        else
        {
            return $b
        }
    }

    [Node] leftRotate ([Node]$top)
    {
        # names are like this for a > shape
        $middle = $top.m_right
        $bottom = $middle.m_left

        # rotate
        $middle.m_left = $top
        $top.m_right = $bottom

        # update heights
        $top.m_height = 1 + [Node]::max($top.m_left.m_height, $top.m_right.m_height)

        # returned root
        return $middle
    }

    [Node] rightRotate ([Node]$top)
    {
        # names are like this for a > shape
        $middle = $top.m_left
        $bottom = $middle.m_right

        # rotate
        $middle.m_right = $top
        $top.m_left = $bottom

        # update heights
        $top.m_height = 1 + [Node]::max($top.m_left.m_height, $top.m_right.m_height)

        # returned root
        return $middle
    }

    [void] balance ()
}
