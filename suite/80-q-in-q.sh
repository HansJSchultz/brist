vlan_setup()
{
    step "Setup VLANs"

    create_br $br0 "vlan_filtering 1 vlan_default_pvid 1" $bports

    bridge vlan add dev $b1 vid 2

    bridge vlan add dev $b2 vid 1
    bridge vlan add dev $b2 vid 2

    bridge vlan add dev $b3 vid 1 untagged
    bridge vlan add dev $b3 vid 2 untagged

    bridge vlan add dev $br0 vid 1 self
    bridge vlan add dev $br0 vid 2 self
}

# Test vlan nested policy on ingress port.
# See if the expected packets are found on the tagged and untagged egress ports when sending
# either tagged or untagged packets to ingress on the port with nested policy.
nested_vlans()
{
    require3loops

    vlan_setup

    bridge vlan help 2> "$t_work/bridge_vlan_help"
    if ! grep -q "\[ nest \]" "$t_work/bridge_vlan_help"; then
        step "Nested vlan feature not supported, skipping."
	rm -f "$t_work/bridge_vlan_help"
        skip
    fi
    rm -f "$t_work/bridge_vlan_help"

    bridge vlan add dev $b1 vid 1 nest

    step "Inject untagged packet"
    capture -f "vlan 1" $h2
    eth -b -i $h1 | { cat; echo nestedstep1data; } | inject $h1

    step "Verify that $h2 sees a packet with a vlan 1 tag"
    report $h2 | grep -q "nestedstep1data" || fail

    step "Inject vlan 1 tagged packet"
    capture -f "vlan 1 and vlan 1" $h2
    eth -b -i $h1 -q 1 | { cat; echo nestedstep2data; } | inject $h1

    step "Verify that $h2 sees a packet with two vlan 1 tags"
    report $h2 | grep -q "nestedstep2data" || fail

    step "Inject vlan 2 packet"
    capture -f "vlan 1 and vlan 2" $h2
    eth -b -i $h1 -q 2 | { cat; echo nestedstep3data; } | inject $h1

    step "Verify that $h2 sees a packet with vlan1 and vlan 2 tags"
    report $h2 | grep -q "nestedstep3data" || fail


    step "Inject untagged packet"
    capture $h3
    eth -b -i $h1 | { cat; echo nestedstep4data; } | inject $h1

    step "Verify that $h3 sees an untagged packet"
    report $h3 | grep -q "nestedstep4data" || fail

    step "Inject untagged packet"
    capture -f "vlan 1" $h3
    eth -b -i $h1 | { cat; echo nestedstep5data; } | inject $h1

    step "Verify that $h3 does not see a packet with a vlan 1 tag"
    report $h3 | grep -q "nestedstep5data" && fail


    step "Inject vlan 1 tagged packet"
    capture -f "vlan 1" $h3
    eth -b -i $h1 -q 1 | { cat; echo nestedstep6data; } | inject $h1

    step "Verify that $h3 sees a packet a vlan 1 tag"
    report $h3 | grep -q "nestedstep6data" || fail

    step "Inject vlan 1 tagged packet"
    capture -f "vlan 1 and vlan 1" $h3
    eth -b -i $h1 -q 1 | { cat; echo nestedstep7data; } | inject $h1

    step "Verify that $h3 does not see a packet with two vlan 1 tags"
    report $h3 | grep -q "nestedstep7data" && fail


    step "Inject vlan 2 tagged packet"
    capture -f "vlan 2" $h3
    eth -b -i $h1 -q 2 | { cat; echo nestedstep8data; } | inject $h1

    step "Verify that $h3 sees a packet with a vlan 2 tag"
    report $h3 | grep -q "nestedstep8data" || fail

    step "Inject vlan 2 tagged packet"
    capture -f "vlan 1 and vlan 2" $h3
    eth -b -i $h1 -q 2 | { cat; echo nestedstep9data; } | inject $h1

    step "Verify that $h3 does not see a packet with vlan 1 and vlan 2 tags"
    report $h3 | grep -q "nestedstep9data" && fail

    pass
}
alltests="$alltests nested_vlans"

# Test vlan forced policy on ingress port.
# See if the expected packets are found on the tagged and untagged egress ports when sending
# either tagged or untagged packets to ingress on the port with forced policy.
forced_vlans()
{
    require3loops

    vlan_setup

    bridge vlan help 2> "$t_work/bridge_vlan_help"
    if ! grep -q "\[ force \]" "$t_work/bridge_vlan_help"; then
        step "Forced vlan feature not supported, skipping."
	rm -f "$t_work/bridge_vlan_help"
        skip
    fi
    rm -f "$t_work/bridge_vlan_help"

    bridge vlan add dev $b1 vid 1 force

    step "Inject untagged traffic"
    capture -f "vlan 1" $h2
    eth -b -i $h1 | { cat; echo forcedstep1data; } | inject $h1

    step "Verify that tagged port $h2 sees a packet with a vlan 1 tag when injecting an untagged packet"
    report $h2  | grep -q "forcedstep1data" || fail

    step "Inject vlan 1 packet"
    capture -f "vlan 1" $h2
    eth -b -i $h1 -q 1 | { cat; echo forcedstep2data; } | inject $h1

    step "Verify that tagged port $h2 sees a packet with a vlan 1 tag when injecting a vlan1 tagged packet"
    report $h2 | grep -q "forcedstep2data" || fail

    step "Inject vlan 1 packet"
    capture -f "vlan 1 and vlan 1" $h2
    eth -b -i $h1 -q 1 | { cat; echo forcedstep3data; } | inject $h1

    step "Verify that tagged port $h2 does not see a packet with two vlan 1 tags when injecting a vlan 1 tagged packet"
    report $h2 | grep -q "forcedstep3data" && fail

    step "Inject vlan 2 packet"
    capture -f "vlan 1" $h2
    eth -b -i $h1 -q 2 | { cat; echo forcedstep4data; } | inject $h1

    step "Verify that tagged port $h2 sees a packet with a vlan 1 tag when injecting a vlan 2 tagged packet"
    report $h2 | grep -q "forcedstep4data" || fail


    step "Inject untagged packet"
    capture $h3
    eth -b -i $h1 | { cat; echo forcedstep5data; } | inject $h1

    step "Verify that untagged port $h3 sees a packet without tags when injecting an untagged packet"
    report $h3 | grep -q "forcedstep5data" || fail

    step "Inject untagged packet"
    capture -f "vlan 1" $h3
    eth -b -i $h1 | { cat; echo forcedstep6data; } | inject $h1

    step "Verify that untagged port $h3 does not see a packet with a vlan 1 tag when injecting an untagged packet"
    report $h3 | grep -q "forcedstep6data" && fail

    step "Inject vlan 1 packet"
    capture $h3
    eth -b -i $h1 -q 1 | { cat; echo forcedstep7data; } | inject $h1

    step "Verify that untagged port $h3 sees a packet without tags when injecting a vlan 1 tagged packet"
    report $h3 | grep -q "forcedstep7data" || fail

    step "Inject vlan 1 packet"
    capture -f "vlan 1" $h3
    eth -b -i $h1 -q 1 | { cat; echo forcedstep8data; } | inject $h1

    step "Verify that untagged port $h3 does not see a packet with vlan 1 tag when injecting a vlan 1 tagged packet"
    report $h3 | grep -q "forcedstep8data" && fail

    step "Inject vlan 2 packet"
    capture $h3
    eth -b -i $h1 -q 2 | { cat; echo forcedstep9data; } | inject $h1

    step "Verify that untagged port $h3 sees a packet without tags when injecting a vlan 2 tagged packet"
    report $h3 | grep -q "forcedstep9data" || fail

    step "Inject vlan 2 packet"
    capture -f "vlan 2" $h3
    eth -b -i $h1 -q 2 | { cat; echo forcedstep10data; } | inject $h1

    step "Verify that untagged port $h3 does not see a packet with vlan 2 tag when injecting a vlan 2 tagged packet"
    report $h3 | grep -q "forcedstep10data" && fail

    pass
}
alltests="$alltests forced_vlans"
