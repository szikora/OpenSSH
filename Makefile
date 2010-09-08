BUILDHOME = $(PWD)
OPENSSHVERSION = 5.6p1

all: package-openssh

clean: clean-openssh

clean-openssh:
	rm -rf openssh
	rm -rf compiled-openssh
	rm -f fetch-openssh build-openssh install-openssh package-openssh

clean-openssh-bin:
	rm -f openssh-$(OPENSSHVERSION).tar.gz
	rm -rf OpenSSH-$(OPENSSHVERSION).pkg
	rm -f OpenSSH-$(OPENSSHVERSION)_for_$(OSX_RELEASE).dmg

openssh-$(OPENSSHVERSION).tar.gz:
	curl -O http://ftp.belnet.be/packages/openbsd/OpenSSH/portable/$@

fetch-openssh: openssh-$(OPENSSHVERSION).tar.gz
	rm -rf openssh
	tar xzvf $^
	mv openssh-$(OPENSSHVERSION) openssh
	touch $@

build-openssh: fetch-openssh
ifeq ("$(OSX_RELEASE)","10.5")
	cd openssh && \
	LIBS="-lresolv" \
	CFLAGS="-isysroot /Developer/SDKs/MacOSX10.5.sdk -arch i386 -arch ppc7400 -mmacosx-version-min=10.5 -g" \
	LDFLAGS="-arch i386 -arch ppc7400" \
	./configure --prefix=/Library/OpenSC  && \
	make && \
	make install-nokeys prefix=$(BUILDHOME)/compiled-openssh/Library/OpenSC
endif
ifeq ("$(OSX_RELEASE)","10.6")
	cd openssh && \
	LIBS="-lresolv" \
	CFLAGS="-arch x86_64 -arch i386" \
	LDFLAGS="-arch x86_64 -arch i386" \
	./configure --prefix=/Library/OpenSC  && \
	make && \
	make install-nokeys prefix=$(BUILDHOME)/compiled-openssh/Library/OpenSC
endif
	rm -f $(BUILDHOME)/compiled-openssh/Library/OpenSC/bin/ssh-keyscan
	rm -f $(BUILDHOME)/compiled-openssh/Library/OpenSC/etc/ssh_host*
	rm -f $(BUILDHOME)/compiled-openssh/Library/OpenSC/etc/sshd_config
	rm -rf $(BUILDHOME)/compiled-openssh/Library/OpenSC/libexec
	rm -f $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man1/ssh-keyscan.1
	rm -f $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man5/sshd_config.5
	rm -rf $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man8
	rm -rf $(BUILDHOME)/compiled-openssh/Library/OpenSC/sbin
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSC/bin/ssh $(BUILDHOME)/compiled-openssh/Library/OpenSC/bin/scssh
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSC/bin/ssh-add $(BUILDHOME)/compiled-openssh/Library/OpenSC/bin/scssh-add
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSC/bin/ssh-agent $(BUILDHOME)/compiled-openssh/Library/OpenSC/bin/scssh-agent
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSC/bin/ssh-keygen $(BUILDHOME)/compiled-openssh/Library/OpenSC/bin/scssh-keygen
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSC/bin/scp $(BUILDHOME)/compiled-openssh/Library/OpenSC/bin/scscp
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSC/bin/sftp $(BUILDHOME)/compiled-openssh/Library/OpenSC/bin/scsftp
	rm -f $(BUILDHOME)/compiled-openssh/Library/OpenSC/bin/slogin
	cd $(BUILDHOME)/compiled-openssh/Library/OpenSC/bin/ && ln -s ./scssh scslogin
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man1/ssh-add.1 $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man1/scssh-add.1
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man1/ssh-agent.1 $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man1/scssh-agent.1
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man1/ssh-keygen.1 $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man1/scssh-keygen.1
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man1/ssh.1 $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man1/scssh.1
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man1/scp.1 $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man1/scscp.1
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man1/sftp.1 $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man1/scsftp.1
	rm -f $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man1/slogin.1
	cd $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man1/ && ln -s ./scssh.1 scslogin.1
	mv $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man5/ssh_config.5 $(BUILDHOME)/compiled-openssh/Library/OpenSC/share/man/man5/scssh_config.5
	mkdir -p $(BUILDHOME)/compiled-openssh/usr/local/bin
	cp $(BUILDHOME)/openssh-uninstall $(BUILDHOME)/compiled-openssh/usr/local/bin
	touch $@

install-openssh: build-openssh
	cp -HR $(BUILDHOME)/compiled-openssh/Library/OpenSC /Library
	touch $@

package-openssh: build-openssh
	/Developer/Applications/Utilities/PackageMaker.app/Contents/MacOS/PackageMaker \
	-r compiled-openssh \
	-o OpenSSH-$(OPENSSHVERSION).pkg \
	-t "OpenSSH with Smartcard support $(OPENSSHVERSION)" \
	-i org.opensc-project.mac.ssh \
	-n $(OPENSSHVERSION) \
	-g 10.4 \
	-b \
	-v \
	--no-relocate \
	-e MacOSX/$(OSX_RELEASE)/resources \
	-s MacOSX/$(OSX_RELEASE)/scripts
	rm -f OpenSSH-$(OPENSSHVERSION)_for_$(OSX_RELEASE).dmg
	hdiutil create -srcfolder OpenSSH-$(OPENSSHVERSION).pkg -volname "OpenSSH with Smartcard support for $(OSX_RELEASE)" OpenSSH-$(OPENSSHVERSION)_for_$(OSX_RELEASE).dmg
	touch $@
