import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import 'package:expenso/services/storage_service.dart';

import 'package:expenso/models/shared_expense.dart';
import 'package:expenso/models/shared_room.dart';
import 'package:expenso/models/shared_settlement.dart';
import 'package:expenso/providers/shared_provider.dart';
import 'package:expenso/providers/social_provider.dart';
import 'package:expenso/features/shared/sheets/add_shared_expense_sheet.dart';
import 'package:expenso/features/shared/sheets/settle_up_sheet.dart';
import 'package:expenso/features/social/sheets/invite_friends_to_room_sheet.dart';

class SharedRoomScreen extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String currencySymbol;
  const SharedRoomScreen({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.currencySymbol,
  });

  @override
  State<SharedRoomScreen> createState() => _SharedRoomScreenState();
}

class _SharedRoomScreenState extends State<SharedRoomScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SharedProvider>().refreshRoom(widget.roomId);
    });
  }

  Future<void> _pickAndUploadImage(SharedRoom room) async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Select Image Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 50);
    if (pickedFile == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Uploading image...')),
    );

    final storageService = StorageService();
    final publicUrl = await storageService.uploadImage(
      file: File(pickedFile.path),
      bucket: 'avatars',
      pathPrefix: 'rooms/${room.id}',
    );

    if (publicUrl != null && mounted) {
      final shared = context.read<SharedProvider>();
      await shared.updateRoomImage(room.id, publicUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image updated successfully!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload image.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shared = context.watch<SharedProvider>();
    final room = shared.roomById(widget.roomId);

    if (room == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Room not found.')),
      );
    }

    final members = shared.membersOf(widget.roomId);
    final expenses = shared.expensesOf(widget.roomId);
    final balances = shared.balancesOf(widget.roomId);
    final myBalance = balances
        .firstWhere(
          (b) => b.userId == widget.currentUserId,
          orElse: () => RoomBalance(userId: widget.currentUserId, net: 0),
        )
        .net;

    final totalSpent = expenses.fold<double>(0, (s, e) => s + e.amount);
    final pendingApprovals =
        shared.pendingApprovalsFor(widget.roomId, widget.currentUserId);
    final pendingProposals =
        shared.pendingProposalsBy(widget.roomId, widget.currentUserId);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(room.typeIcon, size: 20, color: cs.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                room.roomName,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () => _showRoomMenu(context, room),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => shared.refreshRoom(widget.roomId),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            // ---- Hero balance card ----
            _BalanceHero(
              room: room,
              myBalance: myBalance,
              totalSpent: totalSpent,
              currency: widget.currencySymbol,
              memberCount: members.length,
              onEditImage: () => _pickAndUploadImage(room),
            ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.05, end: 0),

            const SizedBox(height: 16),

            // ---- Action row ----
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.add_rounded,
                    label: 'Add',
                    primary: true,
                    onTap: () => _addExpense(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.compare_arrows_rounded,
                    label: 'Settle',
                    badgeCount: pendingApprovals.length,
                    onTap: () => _settleUp(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.person_add_outlined,
                    label: 'Invite',
                    onTap: () => InviteFriendsToRoomSheet.show(
                      context,
                      roomId: widget.roomId,
                      roomName: room.roomName,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ---- Pending approvals (creditor view) ----
            if (pendingApprovals.isNotEmpty) ...[
              _SectionTitle(
                title: 'Pending approvals',
                subtitle:
                    '${pendingApprovals.length} payment${pendingApprovals.length == 1 ? '' : 's'} need your confirmation',
              ),
              const SizedBox(height: 10),
              ...pendingApprovals.map((s) {
                final sender = members
                    .where((m) => m.userId == s.fromUser)
                    .firstOrNull;
                final senderName =
                    sender?.displayName ?? _shortId(s.fromUser);
                return _PendingApprovalCard(
                  settlement: s,
                  fromName: senderName,
                  currency: widget.currencySymbol,
                  onAccept: () => _approvePending(context, s.id, senderName),
                  onReject: () =>
                      _rejectPending(context, s.id, senderName),
                );
              }),
              const SizedBox(height: 24),
            ],

            // ---- My pending proposals (debtor view) ----
            if (pendingProposals.isNotEmpty) ...[
              _SectionTitle(
                title: 'Awaiting confirmation',
                subtitle:
                    'Your ${pendingProposals.length} payment${pendingProposals.length == 1 ? '' : 's'} pending the other side',
              ),
              const SizedBox(height: 10),
              ...pendingProposals.map((s) {
                final receiver = members
                    .where((m) => m.userId == s.toUser)
                    .firstOrNull;
                final name = receiver?.displayName ?? _shortId(s.toUser);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded,
                          size: 18, color: cs.tertiary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Waiting for $name to confirm ${widget.currencySymbol}${s.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],

            // ---- Member balances ----
            if (balances.isNotEmpty) ...[
              _SectionTitle(title: 'Member balances', subtitle: 'Who owes whom'),
              const SizedBox(height: 10),
              ...balances.map((b) {
                final isMe = b.userId == widget.currentUserId;
                final name = isMe
                    ? 'You'
                    : (b.displayName ?? _shortId(b.userId));
                final color = b.net > 0
                    ? const Color(0xFF4E9F3D)
                    : (b.net < 0 ? cs.error : cs.onSurfaceVariant);
                
                final member = shared.membersOf(widget.roomId).where((m) => m.userId == b.userId).firstOrNull;
                final avatarUrl = member?.avatarUrl;

                final social = context.watch<SocialProvider>();
                final isFriend = social.isFriend(b.userId);
                final hasPending = social.hasOutgoingRequestTo(b.userId);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: cs.primary.withOpacity(0.12),
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null ? Text(
                          name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (!isMe && !isFriend)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: hasPending
                              ? Tooltip(
                                  message: 'Request sent',
                                  child: Icon(Icons.hourglass_top_rounded,
                                      size: 18, color: cs.onSurface.withOpacity(0.35)),
                                )
                              : InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    final ok = await social.sendFriendRequest(b.userId);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok
                                              ? 'Friend request sent to $name!'
                                              : social.lastError ?? 'Could not send request.'),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.person_add_outlined, size: 14, color: cs.primary),
                                        const SizedBox(width: 4),
                                        Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary)),
                                      ],
                                    ),
                                  ),
                                ),
                        ),
                      Text(
                        b.net == 0
                            ? 'Even'
                            : (b.net > 0
                                ? '+ ${widget.currencySymbol}${b.net.abs().toStringAsFixed(2)}'
                                : '- ${widget.currencySymbol}${b.net.abs().toStringAsFixed(2)}'),
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],

            // ---- History ----
            _SectionTitle(title: 'History', subtitle: 'Recent activity'),
            const SizedBox(height: 10),
            if (expenses.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 48, color: cs.onSurfaceVariant.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    Text(
                      'No expenses yet.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            else
              ...expenses.asMap().entries.map((entry) {
                final e = entry.value;
                final paidByMe = e.paidBy == widget.currentUserId;
                final memberLookup = members.where((m) => m.userId == e.paidBy);
                final paidByName = paidByMe
                    ? 'You'
                    : (memberLookup.isNotEmpty
                        ? (memberLookup.first.displayName ?? 'Member')
                        : 'Member');
                return _ExpenseRow(
                  expense: e,
                  paidByLabel: paidByName,
                  currency: widget.currencySymbol,
                  index: entry.key,
                  onLongPress: paidByMe
                      ? () => _confirmDeleteExpense(context, e.id)
                      : null,
                );
              }),
          ],
        ),
      ),
    );
  }

  String _shortId(String id) => id.length > 6 ? id.substring(0, 6) : id;

  void _addExpense(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSharedExpenseSheet(
        roomId: widget.roomId,
        currencySymbol: widget.currencySymbol,
      ),
    );
  }

  Future<void> _approvePending(
    BuildContext context,
    String settlementId,
    String senderName,
  ) async {
    HapticFeedback.lightImpact();
    final updated =
        await context.read<SharedProvider>().approveSettlement(settlementId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(updated == null
            ? 'Could not approve. Try again.'
            : 'Confirmed payment from $senderName.'),
      ),
    );
  }

  Future<void> _rejectPending(
    BuildContext context,
    String settlementId,
    String senderName,
  ) async {
    HapticFeedback.lightImpact();
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Reject $senderName\'s payment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'They will be notified that the payment is in dispute.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. didn\'t receive yet',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final reason = reasonCtrl.text.trim();
    final updated = await context.read<SharedProvider>().rejectSettlement(
          settlementId,
          reason: reason.isEmpty ? null : reason,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(updated == null
            ? 'Could not reject. Try again.'
            : 'Rejected $senderName\'s payment.'),
      ),
    );
  }

  void _settleUp(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettleUpSheet(
        roomId: widget.roomId,
        currentUserId: widget.currentUserId,
        currencySymbol: widget.currencySymbol,
      ),
    );
  }

  Future<void> _confirmDeleteExpense(BuildContext context, String id) async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete expense?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context
          .read<SharedProvider>()
          .deleteExpense(widget.roomId, id);
    }
  }

  void _showRoomMenu(BuildContext context, SharedRoom room) {
    final cs = Theme.of(context).colorScheme;
    final shared = context.read<SharedProvider>();
    final isOwner = room.ownerId == widget.currentUserId;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: Text('Copy code · ${room.roomCode}'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: room.roomCode));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied!')),
                  );
                },
              ),
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Rename room'),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _renameDialog(context, room.roomName);
                  },
                ),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: cs.error),
                title: Text('Leave room',
                    style: TextStyle(color: cs.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await _confirm(context,
                      'Leave room?', 'You can rejoin with the code later.');
                  if (ok && context.mounted) {
                    await shared.leaveRoom(widget.roomId);
                    if (context.mounted) Navigator.of(context).pop();
                  }
                },
              ),
              if (isOwner)
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded, color: cs.error),
                  title: Text('Delete room',
                      style: TextStyle(
                          color: cs.error, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await _confirm(context, 'Delete room?',
                        'All members will lose access to this room and its history.');
                    if (ok && context.mounted) {
                      await shared.deleteRoom(widget.roomId);
                      if (context.mounted) Navigator.of(context).pop();
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _renameDialog(BuildContext context, String current) async {
    final ctrl = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename room'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty && context.mounted) {
      await context
          .read<SharedProvider>()
          .renameRoom(widget.roomId, ctrl.text.trim());
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final cs = Theme.of(context).colorScheme;
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return res ?? false;
  }
}

class _BalanceHero extends StatelessWidget {
  final SharedRoom room;
  final double myBalance;
  final double totalSpent;
  final String currency;
  final int memberCount;
  final VoidCallback onEditImage;

  const _BalanceHero({
    required this.room,
    required this.myBalance,
    required this.totalSpent,
    required this.currency,
    required this.memberCount,
    required this.onEditImage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCredit = myBalance >= 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        image: room.imageUrl != null && room.imageUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(room.imageUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.6), BlendMode.darken),
              )
            : null,
        gradient: room.imageUrl == null || room.imageUrl!.isEmpty
            ? const LinearGradient(
                colors: [Color(0xFF1E1E2C), Color(0xFF0F0F16)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  room.roomCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onEditImage,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.people_alt_outlined,
                  size: 14, color: Colors.white.withOpacity(0.7)),
              const SizedBox(width: 4),
              Text(
                '$memberCount',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isCredit ? 'You are owed' : 'You owe',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: myBalance.abs()),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              '$currency${NumberFormat('#,##0.00').format(v)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.wallet_outlined, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(
                'Total spent · $currency${NumberFormat('#,##0.00').format(totalSpent)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;
  final int badgeCount;
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tile = Material(
      color: primary ? cs.primary : cs.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: primary
                ? null
                : Border.all(color: cs.outlineVariant.withOpacity(0.6)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: primary ? cs.onPrimary : cs.primary),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primary ? cs.onPrimary : cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (badgeCount <= 0) return tile;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            decoration: BoxDecoration(
              color: cs.error,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              badgeCount > 9 ? '9+' : '$badgeCount',
              style: TextStyle(
                color: cs.onError,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingApprovalCard extends StatelessWidget {
  final SharedSettlement settlement;
  final String fromName;
  final String currency;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _PendingApprovalCard({
    required this.settlement,
    required this.fromName,
    required this.currency,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.tertiary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: cs.tertiary.withOpacity(0.2),
                child: Text(
                  fromName.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: cs.tertiary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$fromName marked as paid',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Confirm if you received the money.',
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                '$currency${settlement.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.close_rounded, size: 16, color: cs.error),
                  label: Text('Reject',
                      style:
                          TextStyle(color: cs.error, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.error.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onReject,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Accept', style: TextStyle(fontSize: 13)),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 1.5),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final SharedExpense expense;
  final String paidByLabel;
  final String currency;
  final int index;
  final VoidCallback? onLongPress;
  const _ExpenseRow({
    required this.expense,
    required this.paidByLabel,
    required this.currency,
    required this.index,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onLongPress: onLongPress,
          onTap: () {},
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconForCategory(expense.category),
                      size: 20, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$paidByLabel · ${DateFormat('MMM d').format(expense.expenseDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$currency${expense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (40 * index).ms, duration: 280.ms)
        .slideY(begin: 0.06, end: 0, delay: (40 * index).ms);
  }

  IconData _iconForCategory(String? c) {
    switch (c?.toLowerCase()) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'stay':
        return Icons.hotel_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'bills':
        return Icons.receipt_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'health':
        return Icons.healing_rounded;
      default:
        return Icons.payments_rounded;
    }
  }
}
